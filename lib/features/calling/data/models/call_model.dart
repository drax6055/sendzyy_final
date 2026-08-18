import 'package:equatable/equatable.dart';
import 'call_recording_model.dart';
import 'sdp_session_model.dart';

enum CallDirection { businessInitiated, userInitiated }
enum CallStatus { connecting, ringing, accepted, rejected, terminated, failed, completed }

/// Main Call entity for WhatsApp Calling lifecycle.
class CallModel extends Equatable {
  final String callId;             // Unique wacid.* string
  final String to;                 // Callee phone number or BSUID
  final String from;               // Caller phone number or BSUID
  final String? callerName;        // Contact display name
  final CallDirection direction;   // BUSINESS_INITIATED | USER_INITIATED
  final CallStatus status;         // RINGING | ACCEPTED | REJECTED | COMPLETED | FAILED
  final DateTime timestamp;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final SdpSessionModel? session;
  final CallRecordingModel? recording;
  final CallTranscriptModel? transcript;
  final String? deeplinkPayload;
  final String? ctaPayload;
  final String? bizOpaqueCallbackData;

  const CallModel({
    required this.callId,
    required this.to,
    required this.from,
    this.callerName,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.session,
    this.recording,
    this.transcript,
    this.deeplinkPayload,
    this.ctaPayload,
    this.bizOpaqueCallbackData,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final dirString = json['direction'] as String? ?? 'USER_INITIATED';
    final dir = dirString.toUpperCase() == 'BUSINESS_INITIATED'
        ? CallDirection.businessInitiated
        : CallDirection.userInitiated;

    final statusString = (json['status'] is List ? (json['status'] as List).first : json['status']) as String? ?? 'connecting';
    CallStatus callStatus;
    switch (statusString.toUpperCase()) {
      case 'RINGING':
        callStatus = CallStatus.ringing;
        break;
      case 'ACCEPTED':
        callStatus = CallStatus.accepted;
        break;
      case 'REJECTED':
        callStatus = CallStatus.rejected;
        break;
      case 'COMPLETED':
        callStatus = CallStatus.completed;
        break;
      case 'FAILED':
        callStatus = CallStatus.failed;
        break;
      case 'TERMINATED':
      case 'TERMINATE':
        callStatus = CallStatus.terminated;
        break;
      default:
        callStatus = CallStatus.connecting;
    }

    return CallModel(
      callId: json['id'] as String? ?? json['call_id'] as String? ?? '',
      to: json['to'] as String? ?? '',
      from: json['from'] as String? ?? '',
      callerName: json['caller_name'] as String?,
      direction: dir,
      status: callStatus,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      ),
      startTime: json['start_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (int.tryParse(json['start_time'].toString()) ?? 0) * 1000,
            )
          : null,
      endTime: json['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (int.tryParse(json['end_time'].toString()) ?? 0) * 1000,
            )
          : null,
      durationSeconds: json['duration'] != null ? int.tryParse(json['duration'].toString()) : null,
      session: json['session'] != null ? SdpSessionModel.fromJson(json['session'] as Map<String, dynamic>) : null,
      recording: json['call_recording'] != null ? CallRecordingModel.fromJson(json['call_recording'] as Map<String, dynamic>) : null,
      transcript: json['call_transcript'] != null ? CallTranscriptModel.fromJson(json['call_transcript'] as Map<String, dynamic>) : null,
      deeplinkPayload: json['deeplink_payload'] as String?,
      ctaPayload: json['cta_payload'] as String?,
      bizOpaqueCallbackData: json['biz_opaque_callback_data'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': callId,
      'to': to,
      'from': from,
      'caller_name': callerName,
      'direction': direction == CallDirection.businessInitiated ? 'BUSINESS_INITIATED' : 'USER_INITIATED',
      'status': status.name.toUpperCase(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'start_time': startTime != null ? (startTime!.millisecondsSinceEpoch ~/ 1000) : null,
      'end_time': endTime != null ? (endTime!.millisecondsSinceEpoch ~/ 1000) : null,
      'duration': durationSeconds,
      if (session != null) 'session': session!.toJson(),
      if (recording != null) 'call_recording': recording!.toJson(),
      if (transcript != null) 'call_transcript': transcript!.toJson(),
      'deeplink_payload': deeplinkPayload,
      'cta_payload': ctaPayload,
      'biz_opaque_callback_data': bizOpaqueCallbackData,
    };
  }

  CallModel copyWith({
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    SdpSessionModel? session,
    CallRecordingModel? recording,
    CallTranscriptModel? transcript,
  }) {
    return CallModel(
      callId: callId,
      to: to,
      from: from,
      callerName: callerName,
      direction: direction,
      status: status ?? this.status,
      timestamp: timestamp,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      session: session ?? this.session,
      recording: recording ?? this.recording,
      transcript: transcript ?? this.transcript,
      deeplinkPayload: deeplinkPayload,
      ctaPayload: ctaPayload,
      bizOpaqueCallbackData: bizOpaqueCallbackData,
    );
  }

  @override
  List<Object?> get props => [
        callId,
        to,
        from,
        callerName,
        direction,
        status,
        timestamp,
        startTime,
        endTime,
        durationSeconds,
        session,
        recording,
        transcript,
      ];
}
