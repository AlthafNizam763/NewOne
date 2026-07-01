import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final Set<int> _expanded = {};

  static const _faqs = [
    (
      q: 'How do I pair with my partner?',
      a: 'Go to your Profile screen and tap "Pair Device". Share your unique pairing code with your partner. Once they enter it, you will be connected and can start chatting.',
    ),
    (
      q: 'Can I use Hisoka on multiple devices?',
      a: 'Currently Hisoka supports one active session per account. Signing in on a new device will sign you out of the previous one.',
    ),
    (
      q: 'How is my data kept private?',
      a: 'All messages are stored on Firebase with authentication rules that ensure only you and your partner can read them. We do not have access to your message content.',
    ),
    (
      q: 'How do I set up App Lock?',
      a: 'Go to Settings → Privacy & Security → App Lock and toggle it on. You will be prompted to create a 4–6 digit PIN or a password. From then on, the app will require it every time you open it.',
    ),
    (
      q: 'Why are my notifications not working?',
      a: 'Make sure notifications are enabled for Hisoka in your device settings. In the app, check Settings → Notifications and ensure they are turned on. On Android, battery optimization may block background notifications — add Hisoka to the battery optimization whitelist.',
    ),
    (
      q: 'How do I send a voice message?',
      a: 'Tap the microphone icon in the chat input area to start recording. The icon changes to a Send button while recording. Tap Send to send the message, or tap the trash icon to discard it.',
    ),
    (
      q: 'How do I delete my account?',
      a: 'Account deletion can be requested by contacting support at the email below. We will process your request within 7 days.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
            ResponsiveContent(
              padding: EdgeInsets.zero,
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact card
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.elevatedDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.support_agent_rounded,
                                  color: AppColors.primaryGlow),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('We\'re here to help',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const Text(
                                    'Typically reply within 24 hours',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Contact Support',
                          icon: Icons.mail_outline_rounded,
                          onPressed: () => _showContactDialog(context),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 300.ms).slideY(begin: 0.1),

                  const SizedBox(height: 22),
                  const SectionLabel('FREQUENTLY ASKED QUESTIONS'),

                  ...List.generate(_faqs.length, (i) {
                    final faq = _faqs[i];
                    final open = _expanded.contains(i);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppSurface(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(faq.q,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              trailing: AnimatedRotation(
                                turns: open ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primaryGlow),
                              ),
                              onTap: () => setState(() {
                                if (open) {
                                  _expanded.remove(i);
                                } else {
                                  _expanded.add(i);
                                }
                              }),
                            ),
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(faq.a,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                        fontSize: 13)),
                              ),
                              crossFadeState: open
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 200),
                            ),
                          ],
                        ),
                      ).animate().fade(delay: Duration(milliseconds: 60 * i)),
                    );
                  }),

                  const SizedBox(height: 22),
                  const SectionLabel('MORE OPTIONS'),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.bug_report_outlined,
                              color: AppColors.warning),
                          title: const Text('Report a Bug'),
                          subtitle: const Text('Help us improve Hisoka'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showContactDialog(context,
                              subject: 'Bug Report'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lightbulb_outline_rounded,
                              color: AppColors.primaryGlow),
                          title: const Text('Suggest a Feature'),
                          subtitle: const Text('Share your ideas with us'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showContactDialog(context,
                              subject: 'Feature Request'),
                        ),
                      ],
                    ),
                  ).animate().fade(delay: 400.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context, {String subject = 'Support'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reach us at:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const SelectableText(
              'support@hisoka.app',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Please include your user ID and a description of your $subject.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
