// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      uid: json['uid'] as String,
      username: json['username'] as String,
      registeredEmail: json['registeredEmail'] as String,
      partnerUid: json['partnerUid'] as String,
      isOnline: json['isOnline'] as bool? ?? true,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      profilePic: json['profilePic'] as String? ?? '',
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'username': instance.username,
      'registeredEmail': instance.registeredEmail,
      'partnerUid': instance.partnerUid,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'profilePic': instance.profilePic,
    };
