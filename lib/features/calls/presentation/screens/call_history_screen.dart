import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
      ),
      body: AppBackground(
        child: uid == null
            ? const Center(child: Text('Not signed in'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('calls')
                    .where('callerId', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .limit(40)
                    .snapshots(),
                builder: (context, callerSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('calls')
                        .where('calleeId', isEqualTo: uid)
                        .orderBy('createdAt', descending: true)
                        .limit(40)
                        .snapshots(),
                    builder: (context, calleeSnap) {
                      if (callerSnap.connectionState ==
                              ConnectionState.waiting ||
                          calleeSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = [
                        ...(callerSnap.data?.docs ?? []),
                        ...(calleeSnap.data?.docs ?? []),
                      ];
                      docs.sort((a, b) {
                        final aT =
                            (a.data() as Map)['createdAt'] as Timestamp?;
                        final bT =
                            (b.data() as Map)['createdAt'] as Timestamp?;
                        if (aT == null || bT == null) return 0;
                        return bT.compareTo(aT);
                      });

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No call history yet.\nStart a call from the chat screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(24, 16, 24, 96),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final callId = docs[index].id;
                          return _CallTile(
                              callId: callId,
                              data: data,
                              myUid: uid);
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final String callId;
  final Map<String, dynamic> data;
  final String myUid;

  const _CallTile(
      {required this.callId, required this.data, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isCaller = data['callerId'] == myUid;
    final status = data['status'] as String? ?? 'ended';
    final type = data['type'] as String? ?? 'audio';
    final isMissed = status == 'missed' || status == 'rejected';
    final createdAt = data['createdAt'] as Timestamp?;
    final endedAt = data['endedAt'] as Timestamp?;

    String durationStr = '';
    if (createdAt != null && endedAt != null) {
      final diff = endedAt.toDate().difference(createdAt.toDate());
      final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      durationStr = ' · $m:$s';
    }

    final timeStr = createdAt != null
        ? DateFormat('MMM d, HH:mm').format(createdAt.toDate())
        : '';

    final partnerName = isCaller
        ? (data['calleeName'] as String? ?? 'Partner')
        : (data['callerName'] as String? ?? 'Partner');

    final email = FirebaseAuth.instance.currentUser?.email;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryDark,
                backgroundImage: isCaller
                    ? AvatarUtil.getPartnerAvatarProvider(email)
                    : AvatarUtil.getAvatarProvider(email),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Icon(
                    type == 'video' ? Icons.videocam_rounded : Icons.call_rounded,
                    size: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          title: Text(partnerName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Row(
            children: [
              Icon(
                isMissed
                    ? Icons.call_missed_rounded
                    : (isCaller
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded),
                size: 15,
                color: isMissed ? AppColors.error : AppColors.success,
              ),
              const SizedBox(width: 5),
              Text(
                '$timeStr$durationStr',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            tooltip: 'Call back',
            icon: Icon(
              type == 'video'
                  ? Icons.videocam_outlined
                  : Icons.call_outlined,
              color: AppColors.primaryGlow,
            ),
            onPressed: () => context.push('/call/$callId'),
          ),
        ),
      ),
    );
  }
}
