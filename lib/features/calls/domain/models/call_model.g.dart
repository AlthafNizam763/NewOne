// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CallModelImpl _$$CallModelImplFromJson(Map<String, dynamic> json) =>
    _$CallModelImpl(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      callerName: json['callerName'] as String,
      callerPic: json['callerPic'] as String,
      receiverId: json['receiverId'] as String,
      receiverName: json['receiverName'] as String,
      receiverPic: json['receiverPic'] as String,
      type: $enumDecode(_$CallTypeEnumMap, json['type']),
      status: $enumDecode(_$CallStatusEnumMap, json['status']),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      channelId: json['channelId'] as String?,
    );

Map<String, dynamic> _$$CallModelImplToJson(_$CallModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'callerId': instance.callerId,
      'callerName': instance.callerName,
      'callerPic': instance.callerPic,
      'receiverId': instance.receiverId,
      'receiverName': instance.receiverName,
      'receiverPic': instance.receiverPic,
      'type': _$CallTypeEnumMap[instance.type]!,
      'status': _$CallStatusEnumMap[instance.status]!,
      'startedAt': instance.startedAt.toIso8601String(),
      'endedAt': instance.endedAt?.toIso8601String(),
      'channelId': instance.channelId,
    };

const _$CallTypeEnumMap = {
  CallType.audio: 'audio',
  CallType.video: 'video',
};

const _$CallStatusEnumMap = {
  CallStatus.dialing: 'dialing',
  CallStatus.ringing: 'ringing',
  CallStatus.accepted: 'accepted',
  CallStatus.rejected: 'rejected',
  CallStatus.missed: 'missed',
  CallStatus.ended: 'ended',
};
