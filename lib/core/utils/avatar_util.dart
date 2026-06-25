import 'package:flutter/material.dart';

class AvatarUtil {
  static String getAvatarPath(String? email) {
    if (email == null || email.isEmpty) return 'assets/images/profile_1.jpg';
    final username = email.split('@')[0].toLowerCase();
    // Use hash to consistently assign one of the two profile pictures
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
