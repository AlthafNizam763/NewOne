// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageModelImpl _$$MessageModelImplFromJson(Map<String, dynamic> json) =>
    _$MessageModelImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      text: json['text'] as String,
      type: $enumDecode(_$MessageTypeEnumMap, json['type']),
      timeSent: DateTime.parse(json['timeSent'] as String),
      status: $enumDecode(_$MessageStatusEnumMap, json['status']),
      replyToMessageId: json['replyToMessageId'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$MessageModelImplToJson(_$MessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'text': instance.text,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'timeSent': instance.timeSent.toIso8601String(),
      'status': _$MessageStatusEnumMap[instance.status]!,
      'replyToMessageId': instance.replyToMessageId,
      'mediaUrl': instance.mediaUrl,
      'isDeleted': instance.isDeleted,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.video: 'video',
  MessageType.audio: 'audio',
  MessageType.location: 'location',
  MessageType.contact: 'contact',
};

const _$MessageStatusEnumMap = {
  MessageStatus.sent: 'sent',
  MessageStatus.delivered: 'delivered',
  MessageStatus.read: 'read',
};
