// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StoryModelImpl _$$StoryModelImplFromJson(Map<String, dynamic> json) =>
    _$StoryModelImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      userPic: json['userPic'] as String,
      type: $enumDecode(_$StoryTypeEnumMap, json['type']),
      mediaUrl: json['mediaUrl'] as String?,
      textContent: json['textContent'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      viewers: (json['viewers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$$StoryModelImplToJson(_$StoryModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'userPic': instance.userPic,
      'type': _$StoryTypeEnumMap[instance.type]!,
      'mediaUrl': instance.mediaUrl,
      'textContent': instance.textContent,
      'backgroundColor': instance.backgroundColor,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'viewers': instance.viewers,
      'reactions': instance.reactions,
    };

const _$StoryTypeEnumMap = {
  StoryType.text: 'text',
  StoryType.image: 'image',
  StoryType.video: 'video',
};
