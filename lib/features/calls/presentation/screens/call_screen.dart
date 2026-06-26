import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  const CallScreen({super.key, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool isMuted = false;
  bool isVideoEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive video call feel
      body: Stack(
        children: [
          // Remote Video Stream Placeholder
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=800',
              fit: BoxFit.cover,
            ),
          ),

          // Gradient overlay for text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // Header
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: const Column(
                  children: [
                    Text('Partner',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('02:45',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ).animate().fade().slideY(begin: -0.5),
              ),
            ),
          ),

          // Floating Local Video Preview
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
                  image: const DecorationImage(
                    image: NetworkImage('https://i.pravatar.cc/300'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ).animate().scale(delay: 300.ms),
          ),

          // Floating Glass Call Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
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
                        _buildControlButton(
                          icon: isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          bgColor: isMuted
                              ? AppColors.error
                              : Colors.white.withValues(alpha: 0.18),
                          onTap: () => setState(() => isMuted = !isMuted),
                        ),
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: Colors.white,
                          bgColor: AppColors.error,
                          size: 60,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        _buildControlButton(
                          icon: isVideoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          color: Colors.white,
                          bgColor: isVideoEnabled
                              ? Colors.white.withValues(alpha: 0.18)
                              : AppColors.error,
                          onTap: () =>
                              setState(() => isVideoEnabled = !isVideoEnabled),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1.0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon,
      required Color color,
      required Color bgColor,
      required VoidCallback onTap,
      double size = 50}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
