import 'dart:math' show sin, pi;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/badge_service.dart';
import '../../core/services/push_notification_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Infinite loops — alive for the entire splash lifetime.
  late final AnimationController _pulseCtrl;  // glow rings breath, 3 s period
  late final AnimationController _orbitCtrl;  // arc spinner,       1.8 s period

  // Single-shot — plays when the splash is ready to dismiss.
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    // Force a black status bar so there is no coloured stripe on top.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    // Resolve auth destination and enforce a minimum display time in parallel
    // so the premium animation always plays fully — without adding serial delays.
    final destFuture = _resolveDestination();
    await Future.delayed(const Duration(milliseconds: 2200));
    final dest = await destFuture;

    if (!mounted) return;

    // Sync the app-icon badge with the server-side unread count now that
    // we have a confirmed authenticated user.
    await BadgeService.syncFromFirestore();

    // Fade the entire splash out, then navigate.
    await _exitCtrl.forward();
    if (mounted) context.go(dest);
  }

  Future<String> _resolveDestination() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return '/login';

    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('app_lock_enabled') ?? false;

    // Terminated-state notification tap — route straight to the relevant
    // screen (lock screen takes precedence if app lock is enabled).
    final notifData = ref
        .read(pushNotificationServiceProvider)
        .consumeInitialNotification();
    if (notifData != null && notifData['type'] == 'chat') {
      return isLocked ? '/lock' : '/chat';
    }

    return isLocked ? '/lock' : '/home';
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _exitCtrl,
          builder: (_, child) => Opacity(
            opacity: _exitOpacity.value,
            child: child,
          ),
          child: _SplashBody(
            pulseCtrl: _pulseCtrl,
            orbitCtrl: _orbitCtrl,
          ),
        ),
      ),
    );
  }
}

// ── Body (rebuilt only when pulse/orbit change — isolated from the exit Opacity)

class _SplashBody extends StatelessWidget {
  final AnimationController pulseCtrl;
  final AnimationController orbitCtrl;

  const _SplashBody({required this.pulseCtrl, required this.orbitCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background: deep black with subtle radial warmth ────────
          _Background(pulseCtrl: pulseCtrl),

          // ── 2. Content column ─────────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo + pulsing rings
              _LogoSection(pulseCtrl: pulseCtrl),

              const SizedBox(height: 36),

              // App name + divider + tagline
              const _TextSection(),

              const Spacer(flex: 2),

              // Rotating arc spinner
              _ArcSpinner(orbitCtrl: orbitCtrl)
                  .animate()
                  .fade(delay: 900.ms, duration: 400.ms),

              const SizedBox(height: 60),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Background ────────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _Background({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient — very dark, not pure flat black so depth reads.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 1.3,
              colors: [Color(0xFF141414), Color(0xFF080808), Color(0xFF000000)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // Breathing ambient glow behind the logo area.
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) {
            final t = sin(pulseCtrl.value * 2 * pi) * 0.5 + 0.5;
            return Center(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.03 + 0.04 * t),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Logo section ──────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _LogoSection({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      // child is built once; AnimatedBuilder rebuilds only the rings + shadow.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/images/logo.png',
          width: 128,
          height: 128,
          fit: BoxFit.cover,
        ),
      )
          .animate()
          .fade(duration: 640.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.48, 0.48),
            end: const Offset(1, 1),
            duration: 840.ms,
            curve: Curves.easeOutBack,
          ),
      builder: (_, child) {
        final t = sin(pulseCtrl.value * 2 * pi) * 0.5 + 0.5;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost diffuse halo
            Container(
              width: 206 + 16 * t,
              height: 206 + 16 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04 + 0.035 * t),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Outer breathing ring
            Container(
              width: 178 + 10 * t,
              height: 178 + 10 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.055 + 0.055 * t),
                  width: 1,
                ),
              ),
            ),

            // Inner ring, slightly brighter
            Container(
              width: 158 + 6 * t,
              height: 158 + 6 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08 + 0.07 * t),
                  width: 1,
                ),
              ),
            ),

            // White rounded-rect container that frames the logo
            // (mirrors the app-icon shape the user sees on the launcher).
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  // Diffuse glow — intensity breathes with pulse.
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.14 + 0.14 * t),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                  // Tight crisp halo
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06 + 0.06 * t),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

// ── Text section ──────────────────────────────────────────────────────────────

class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App name — all-caps, wide tracking for premium feel.
        const Text(
          'HISOKA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            height: 1,
          ),
        )
            .animate()
            .fade(delay: 360.ms, duration: 560.ms)
            .slideY(
              begin: 0.25,
              end: 0,
              delay: 360.ms,
              duration: 560.ms,
              curve: Curves.easeOut,
            ),

        const SizedBox(height: 14),

        // Thin divider that grows outward from the centre.
        Container(
          width: 44,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
        )
            .animate()
            .fade(delay: 540.ms, duration: 480.ms)
            .scaleX(
              begin: 0,
              end: 1,
              delay: 540.ms,
              duration: 480.ms,
              curve: Curves.easeOut,
            ),

        const SizedBox(height: 14),

        // Tagline.
        const Text(
          'Private messaging, calmly organized.',
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ).animate().fade(delay: 680.ms, duration: 560.ms),
      ],
    );
  }
}

// ── Arc spinner ───────────────────────────────────────────────────────────────

class _ArcSpinner extends StatelessWidget {
  final AnimationController orbitCtrl;
  const _ArcSpinner({required this.orbitCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbitCtrl,
      builder: (_, __) => CustomPaint(
        size: const Size(44, 44),
        painter: _ArcPainter(progress: orbitCtrl.value),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 1.5;
    const strokeW = 1.5;

    // Faint full-circle track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Bright sweeping arc — start angle rotates with progress.
    // Subtract π/2 so the arc begins at 12 o'clock.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * pi - pi / 2,
      1.35, // ~77° sweep — long enough to read as motion
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
