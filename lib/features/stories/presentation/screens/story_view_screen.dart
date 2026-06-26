import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';

class StoryViewScreen extends StatefulWidget {
  final String storyId;
  const StoryViewScreen({super.key, required this.storyId});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Story duration
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) context.pop();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _progressController.stop(),
        onTapUp: (_) => _progressController.forward(),
        child: Stack(
          children: [
            // Story Content
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1516245834210-c4c142787335?auto=format&fit=crop&q=80&w=800',
                fit: BoxFit.cover,
              ),
            ),

            // Top Gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 8.0),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _progressController.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 2,
                        );
                      },
                    ),
                  ),

                  // User Info Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                            radius: 16,
                            backgroundImage:
                                NetworkImage('https://i.pravatar.cc/150')),
                        const SizedBox(width: 8),
                        const Text('Partner',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('2h',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7))),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Reply / Reaction Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 32, top: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.borderStrong,
                              width: AppBrutal.border),
                          borderRadius: BorderRadius.circular(AppBrutal.radius),
                        ),
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Reply...',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.favorite_outline,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 16),
                    const Icon(Icons.send, color: Colors.white, size: 28),
                  ],
                ),
              ).animate().slideY(begin: 1.0, curve: Curves.easeOutQuart),
            ),
          ],
        ),
      ),
    );
  }
}
