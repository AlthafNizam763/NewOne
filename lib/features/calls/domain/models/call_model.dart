import 'package:freezed_annotation/freezed_annotation.dart';

part 'call_model.freezed.dart';
part 'call_model.g.dart';

enum CallType { audio, video }

enum CallStatus { dialing, ringing, accepted, rejected, missed, ended }

@freezed
class CallModel with _$CallModel {
  const factory CallModel({
    required String id,
    required String callerId,
    required String callerName,
    required String callerPic,
    required String receiverId,
    required String receiverName,
    required String receiverPic,
    required CallType type,
    required CallStatus status,
    required DateTime startedAt,
    DateTime? endedAt,
    String? channelId,
  }) = _CallModel;

  factory CallModel.fromJson(Map<String, dynamic> json) =>
      _$CallModelFromJson(json);
}
