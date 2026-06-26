import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(
            tooltip: 'Start call',
            icon: const Icon(Icons.add_call),
            onPressed: () => context.push('/call/test_call_id'),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              maxWidth: 760,
              child: AppSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < 5; index++) ...[
                      _CallTile(index: index),
                      if (index != 4) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  final int index;

  const _CallTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final isMissed = index % 3 == 0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryDark,
        child: Text('${index + 1}',
            style: const TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w900)),
      ),
      title: Text('Partner ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Row(
        children: [
          Icon(
            isMissed ? Icons.call_missed_rounded : Icons.call_made_rounded,
            size: 16,
            color: isMissed ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 6),
          Text(isMissed ? 'Missed today, 10:30 AM' : 'Today, 10:30 AM'),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Video call',
        icon: const Icon(Icons.videocam_outlined, color: AppColors.primaryGlow),
        onPressed: () => context.push('/call/test_call_id'),
      ),
    );
  }
}
