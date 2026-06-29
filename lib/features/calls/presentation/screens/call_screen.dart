import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/call_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  const CallScreen({super.key, required this.callId});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  StreamSubscription? _localSub;
  StreamSubscription? _remoteSub;
  StreamSubscription? _statusSub;

  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String _callerName = 'Partner';
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _fetchCallMeta();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    setState(() => _renderersReady = true);

    final sig = ref.read(callSignalingServiceProvider);
    _localSub = sig.localStream.listen((stream) {
      if (!mounted) return;
      setState(() => _localRenderer.srcObject = stream);
    });
    _remoteSub = sig.remoteStream.listen((stream) {
      if (!mounted) return;
      setState(() => _remoteRenderer.srcObject = stream);
    });
  }

  Future<void> _fetchCallMeta() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .get();
      if (!mounted || !snap.exists) return;
      final data = snap.data()!;
      setState(() => _callerName = data['callerName'] as String? ?? 'Partner');

      // Watch for call ended by the other side
      _statusSub = FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        final status = s.data()?['status'] as String?;
        if (status == 'ended' || status == 'rejected') {
          _endAndPop();
        }
      });
    } catch (e) {
      debugPrint('CallScreen._fetchCallMeta error: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _endAndPop() {
    _timer?.cancel();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _localSub?.cancel();
    _remoteSub?.cancel();
    _statusSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callControllerProvider);
    final isIncoming = callState.status == CallStatus.incoming &&
        callState.callId == widget.callId;
    final isOutgoing = callState.status == CallStatus.outgoing &&
        callState.callId == widget.callId;
    final isActive = callState.status == CallStatus.active;
    final isVideo =
        (callState.type ?? 'audio') == 'video' && callState.isVideoEnabled;

    // Start timer when active
    if (isActive && !(_timer?.isActive ?? false)) _startTimer();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Remote video (background) ────────────────────────────────
          if (_renderersReady && isActive)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0D1B2A), Color(0xFF1A1A2E)],
                  ),
                ),
              ),
            ),

          // ── Gradient scrim for readability ───────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _callerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIncoming
                          ? 'Incoming ${callState.type ?? 'audio'} call…'
                          : isOutgoing
                              ? 'Calling…'
                              : isActive
                                  ? _formatElapsed()
                                  : 'Connecting…',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ).animate().fade().slideY(begin: -0.4, curve: Curves.easeOut),
              ),
            ),
          ),

          // ── Local video (PiP) ────────────────────────────────────────
          if (_renderersReady && isActive && isVideo)
            Positioned(
              top: 100,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppGlass.radius),
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppGlass.radius),
                    border: Border.all(color: AppColors.borderStrong),
                    boxShadow: AppGlass.softShadow(),
                  ),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ).animate().scale(delay: 300.ms),
            ),

          // ── Call controls ────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: isIncoming
                ? _buildIncomingControls(callState)
                : _buildActiveControls(callState),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingControls(CallState callState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reject
        _RoundButton(
          icon: Icons.call_end_rounded,
          color: AppColors.error,
          size: 70,
          label: 'Decline',
          onTap: () async {
            await ref.read(callControllerProvider.notifier).rejectCall();
            if (mounted) context.pop();
          },
        ),
        // Accept
        _RoundButton(
          icon: Icons.call_rounded,
          color: AppColors.success,
          size: 70,
          label: 'Accept',
          onTap: () async {
            await ref.read(callControllerProvider.notifier).answerCall();
          },
        ),
      ],
    ).animate().slideY(begin: 1.0, curve: Curves.easeOutBack);
  }

  Widget _buildActiveControls(CallState callState) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppGlass.radiusPill),
        boxShadow: AppGlass.softShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppGlass.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppGlass.blurSigma, sigmaY: AppGlass.blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppGlass.radiusPill),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  bgColor: callState.isMuted
                      ? AppColors.error
                      : Colors.white.withValues(alpha: 0.15),
                  onTap: () =>
                      ref.read(callControllerProvider.notifier).toggleMute(),
                ),
                if (callState.type == 'video')
                  _ControlButton(
                    icon: Icons.flip_camera_ios_rounded,
                    bgColor: Colors.white.withValues(alpha: 0.15),
                    onTap: () =>
                        ref.read(callControllerProvider.notifier).switchCamera(),
                  ),
                _ControlButton(
                  icon: Icons.call_end_rounded,
                  bgColor: AppColors.error,
                  size: 60,
                  onTap: () async {
                    await ref.read(callControllerProvider.notifier).endCall();
                    if (mounted) context.pop();
                  },
                ),
                if (callState.type == 'video')
                  _ControlButton(
                    icon: callState.isVideoEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    bgColor: callState.isVideoEnabled
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.error,
                    onTap: () =>
                        ref.read(callControllerProvider.notifier).toggleVideo(),
                  )
                else
                  _ControlButton(
                    icon: Icons.volume_up_rounded,
                    bgColor: Colors.white.withValues(alpha: 0.15),
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1.0, curve: Curves.easeOutBack);
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.bgColor,
    required this.onTap,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.46),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String label;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
