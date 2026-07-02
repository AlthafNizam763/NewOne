import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging, Message } from "firebase-admin/messaging";

// ── Admin SDK bootstrap ───────────────────────────────────────────────────────
// Called once. The Admin SDK reads credentials from the Cloud Function
// runtime automatically — no service-account JSON ever touches client code.
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// Must match the channel ID registered in push_notification_service.dart
const CHAT_CHANNEL_ID = "chat_messages_channel";

// ── Helper: resolve a human-readable notification body ────────────────────────
function buildBody(type: string, text: string): string {
  switch (type) {
    case "image":    return "📷 Photo";
    case "audio":    return "🎤 Voice message";
    case "video":    return "🎥 Video";
    case "location": return "📍 Location";
    default: {
      const trimmed = text?.trim() || "New message";
      return trimmed.length > 100 ? `${trimmed.substring(0, 97)}…` : trimmed;
    }
  }
}

// ── Cloud Function: sendChatNotification ──────────────────────────────────────
// Triggered whenever a new message document is created inside any chat room.
// Uses Firebase Admin SDK → FCM HTTP v1 API internally.
// No server key, no legacy endpoint, no client-side secrets.
export const sendChatNotification = onDocumentCreated(
  {
    document: "chat_rooms/{roomId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const msg = snap.data();
    const { roomId } = event.params;

    const senderId   = msg.sender   as string | undefined;
    const receiverId = msg.receiver as string | undefined;

    // ── Guard rails ───────────────────────────────────────────────────────────
    if (!senderId || !receiverId) {
      console.log("[FCM] Skipping: missing sender/receiver fields");
      return null;
    }
    if (msg.isDeleted === true) {
      console.log("[FCM] Skipping: message is marked deleted");
      return null;
    }

    // ── Read receiver token ───────────────────────────────────────────────────
    const receiverRef  = db.collection("users").doc(receiverId);
    const receiverSnap = await receiverRef.get();

    if (!receiverSnap.exists) {
      console.log(`[FCM] Receiver ${receiverId} not in Firestore — skipping`);
      return null;
    }

    const fcmToken = receiverSnap.data()?.fcmToken as string | undefined;
    if (!fcmToken) {
      // Receiver is logged out or hasn't granted permission yet — expected path
      console.log(`[FCM] No token for ${receiverId} — skipping`);
      return null;
    }

    // ── Read sender name ──────────────────────────────────────────────────────
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = (senderSnap.data()?.username as string | undefined) ?? "Someone";

    // ── Build payload ─────────────────────────────────────────────────────────
    const type = (msg.type as string) || "text";
    const body = buildBody(type, msg.text as string);

    const fcmMessage: Message = {
      token: fcmToken,

      // notification block → shown by the OS in background/terminated state
      notification: {
        title: senderName,
        body,
      },

      // data block → available to Flutter in ALL states (fg / bg / terminated)
      data: {
        type:       "chat",
        roomId,
        senderId,
        senderName,
        message:    body,
        timestamp:  msg.createdAt?.toMillis?.()?.toString() ?? "",
      },

      android: {
        priority: "high",
        notification: {
          channelId:              CHAT_CHANNEL_ID,
          priority:               "max",
          defaultSound:           true,
          defaultVibrateTimings:  true,
          // Tells the OS to route the tap event back to the Flutter engine
          clickAction:            "FLUTTER_NOTIFICATION_CLICK",
        },
      },

      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    // ── Send ──────────────────────────────────────────────────────────────────
    try {
      const messageId = await messaging.send(fcmMessage);
      console.log(
        `[FCM] OK → receiver=${receiverId} room=${roomId} msgId=${messageId}`
      );
    } catch (err: unknown) {
      const error = err as { code?: string; message?: string };

      // Stale token: device was factory-reset or app was uninstalled.
      // Remove it so future sends don't waste a round-trip.
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.warn(
          `[FCM] Stale token for ${receiverId} — pruning from Firestore`
        );
        await receiverRef.update({
          fcmToken:           FieldValue.delete(),
          fcmTokenUpdatedAt:  FieldValue.delete(),
        });
        return null; // Don't retry — stale token is permanent until user logs in again
      }

      // Unexpected error: re-throw so Cloud Functions retries automatically
      console.error(`[FCM] Unexpected send error for ${receiverId}:`, error);
      throw error;
    }

    return null;
  }
);

// ── Cloud Function: sendAlertNotification ─────────────────────────────────────
// Triggered when User A writes to alerts/{alertId}.
// Sends a high-priority "🚨 Alert" push to User B's device via Admin SDK.
const ALERT_CHANNEL_ID = "alerts_channel";

export const sendAlertNotification = onDocumentCreated(
  {
    document: "alerts/{alertId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const alert = snap.data();
    const senderId   = alert.senderId   as string | undefined;
    const receiverId = alert.receiverId as string | undefined;
    const roomId     = alert.roomId     as string | undefined;

    if (!senderId || !receiverId) {
      console.log("[FCM] Alert: missing senderId/receiverId — skipping");
      return null;
    }

    // Read receiver FCM token
    const receiverRef  = db.collection("users").doc(receiverId);
    const receiverSnap = await receiverRef.get();

    if (!receiverSnap.exists) {
      console.log(`[FCM] Alert receiver ${receiverId} not found — skipping`);
      return null;
    }

    const fcmToken = receiverSnap.data()?.fcmToken as string | undefined;
    if (!fcmToken) {
      console.log(`[FCM] Alert: no token for ${receiverId} — skipping`);
      return null;
    }

    // Read sender username from Firestore (authoritative, client can't spoof)
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = (senderSnap.data()?.username as string | undefined) ?? "Someone";

    const body = `${senderName} wants your attention.`;

    const fcmMessage: Message = {
      token: fcmToken,
      notification: {
        title: "🚨 Alert",
        body,
      },
      data: {
        type:       "alert",
        alertId:    event.params.alertId,
        senderId,
        senderName,
        receiverId,
        roomId:     roomId ?? "",
        message:    body,
      },
      android: {
        priority: "high",
        notification: {
          channelId:             ALERT_CHANNEL_ID,
          priority:              "max",
          defaultSound:          true,
          defaultVibrateTimings: true,
          clickAction:           "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const messageId = await messaging.send(fcmMessage);
      console.log(
        `[FCM] Alert OK → receiver=${receiverId} alertId=${event.params.alertId} msgId=${messageId}`
      );
    } catch (err: unknown) {
      const error = err as { code?: string; message?: string };
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.warn(`[FCM] Alert: stale token for ${receiverId} — pruning`);
        await receiverRef.update({
          fcmToken:          FieldValue.delete(),
          fcmTokenUpdatedAt: FieldValue.delete(),
        });
        return null;
      }
      console.error(`[FCM] Alert send error for ${receiverId}:`, error);
      throw error;
    }

    return null;
  }
);
