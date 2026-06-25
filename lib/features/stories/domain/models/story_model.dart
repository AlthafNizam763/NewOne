import 'package:freezed_annotation/freezed_annotation.dart';

part 'story_model.freezed.dart';
part 'story_model.g.dart';

enum StoryType { text, image, video }

@freezed
class StoryModel with _$StoryModel {
  const factory StoryModel({
    required String id,
    required String userId,
    required String username,
    required String userPic,
    required StoryType type,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    required DateTime expiresAt,
    required DateTime createdAt,
    @Default([]) List<String> viewers,
    @Default({}) Map<String, String> reactions, // userId : reactionEmoji
  }) = _StoryModel;

  factory StoryModel.fromJson(Map<String, dynamic> json) =>
      _$StoryModelFromJson(json);
}
