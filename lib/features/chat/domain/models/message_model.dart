import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

enum MessageType { text, image, video, audio, location, contact }

enum MessageStatus { sent, delivered, read }

@freezed
class MessageModel with _$MessageModel {
  const factory MessageModel({
    required String id,
    required String senderId,
    required String receiverId,
    required String text,
    required MessageType type,
    required DateTime timeSent,
    required MessageStatus status,
    String? replyToMessageId,
    String? mediaUrl,
    @Default(false) bool isDeleted,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);
}
