import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: SafeArea(
        child: GlassmorphicContainer(
          width: double.infinity,
          height: 70,
          borderRadius: 35,
          blur: 20,
          alignment: Alignment.center,
          border: 1.5,
          linearGradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.05),
            ],
          ),
          borderGradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, 0, Icons.chat_bubble_rounded, 'Chats'),
              _buildNavItem(context, 1, Icons.call_rounded, 'Calls'),
              _buildNavItem(context, 2, Icons.camera_rounded, 'Stories'),
              _buildNavItem(context, 3, Icons.people_rounded, 'Community'),
              _buildNavItem(context, 4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ).animate().slideY(
            begin: 1.5, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primaryDark : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding:
            EdgeInsets.symmetric(horizontal: isSelected ? 16 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryDark.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ).animate().fade().slideX(begin: -0.2, end: 0),
            ]
          ],
        ),
      ),
    );
  }
}
