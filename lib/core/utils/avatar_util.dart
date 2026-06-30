import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AvatarUtil {
  static String getAvatarPath(String? email) {
    if (email == null || email.isEmpty) return 'assets/images/profile_1.jpg';
    final username = email.split('@')[0].toLowerCase();
    return username.hashCode % 2 == 0
        ? 'assets/images/profile_1.jpg'
        : 'assets/images/profile_2.jpg';
  }

  static ImageProvider getAvatarProvider(String? email) {
    return AssetImage(getAvatarPath(email));
  }

  static String getPartnerAvatarPath(String? email) {
    if (email == null || email.isEmpty) return 'assets/images/profile_2.jpg';
    final username = email.split('@')[0].toLowerCase();
    return username.hashCode % 2 == 0
        ? 'assets/images/profile_2.jpg'
        : 'assets/images/profile_1.jpg';
  }

  static ImageProvider getPartnerAvatarProvider(String? email) {
    return AssetImage(getPartnerAvatarPath(email));
  }
}

/// Displays a circular avatar that streams the user's real Firestore avatarUrl.
/// Falls back to local asset if no URL is set or if the load fails.
class UserAvatar extends StatelessWidget {
  final String? uid;
  final String? fallbackEmail;
  final bool isPartner;
  final double radius;

  const UserAvatar({
    super.key,
    this.uid,
    this.fallbackEmail,
    this.isPartner = false,
    this.radius = 20,
  });

  ImageProvider get _fallback => isPartner
      ? AvatarUtil.getPartnerAvatarProvider(fallbackEmail)
      : AvatarUtil.getAvatarProvider(fallbackEmail);

  @override
  Widget build(BuildContext context) {
    if (uid == null || uid!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.elevatedDark,
        backgroundImage: _fallback,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final url = data?['avatarUrl'] as String?;
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.elevatedDark,
          backgroundImage: (url != null && url.isNotEmpty)
              ? NetworkImage(url)
              : _fallback,
          onBackgroundImageError: (_, __) {},
        );
      },
    );
  }
}
