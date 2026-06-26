import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_chrome.dart';

class StoriesListScreen extends StatelessWidget {
  const StoriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        actions: [
          IconButton(
              tooltip: 'Add story',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () {}),
        ],
      ),
      body: AppBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveContent(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                maxWidth: 900,
                child: AppSurface(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: SizedBox(
                    height: 96,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final isMyStory = index == 0;
                        return GestureDetector(
                          onTap: () => context.push('/story/test_story_id'),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(AppBrutal.radius),
                                        gradient: isMyStory
                                            ? null
                                            : AppColors.primaryGradient,
                                        color: isMyStory
                                            ? AppColors.elevatedDark
                                            : null,
                                        border: Border.all(
                                            color: AppColors.borderStrong,
                                            width: AppBrutal.border),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(AppBrutal.radius - 1),
                                        child: Image.asset(
                                          isMyStory
                                              ? 'assets/images/profile_1.jpg'
                                              : 'assets/images/profile_2.jpg',
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    if (isMyStory)
                                      const Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: CircleAvatar(
                                          radius: 11,
                                          backgroundColor:
                                              AppColors.primaryDark,
                                          child: Icon(Icons.add,
                                              size: 15,
                                              color: AppColors.textDark),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isMyStory ? 'My Story' : 'Friend $index',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: ResponsiveContent(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 10),
                maxWidth: 900,
                child: SectionLabel('RECENT UPDATES'),
              ),
            ),
            SliverToBoxAdapter(
              child: ResponsiveContent(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                maxWidth: 900,
                child: AppSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0; index < 10; index++) ...[
                        ListTile(
                          onTap: () => context.push('/story/test_story_id'),
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppBrutal.radius),
                                gradient: AppColors.primaryGradient,
                                border: Border.all(
                                    color: AppColors.borderStrong,
                                    width: AppBrutal.border)),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppBrutal.radius - 1),
                              child: Image.asset('assets/images/profile_2.jpg',
                                  width: 44, height: 44, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text('Friend $index',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('2 hours ago'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                        if (index != 9) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
