import 'package:equatable/equatable.dart';

/// Models call audio recording metadata received via `call_recording_available` webhook.
class CallRecordingModel extends Equatable {
  final String id;
  final String sha256;
  final String mimeType;
  final String url;

  const CallRecordingModel({
    required this.id,
    required this.sha256,
    required this.mimeType,
    required this.url,
  });

  factory CallRecordingModel.fromJson(Map<String, dynamic> json) {
    final audio = json['audio'] as Map<String, dynamic>? ?? json;
    return CallRecordingModel(
      id: audio['id'] as String? ?? '',
      sha256: audio['sha256'] as String? ?? '',
      mimeType: audio['mime_type'] as String? ?? 'audio/ogg; codecs=opus',
      url: audio['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sha256': sha256,
      'mime_type': mimeType,
      'url': url,
    };
  }

  @override
  List<Object?> get props => [id, sha256, mimeType, url];
}

/// Models call transcript document metadata received via `call_transcription_available` webhook.
class CallTranscriptModel extends Equatable {
  final String id;
  final String sha256;
  final String mimeType;
  final String url;

  const CallTranscriptModel({
    required this.id,
    required this.sha256,
    required this.mimeType,
    required this.url,
  });

  factory CallTranscriptModel.fromJson(Map<String, dynamic> json) {
    final doc = json['document'] as Map<String, dynamic>? ?? json;
    return CallTranscriptModel(
      id: doc['id'] as String? ?? '',
      sha256: doc['sha256'] as String? ?? '',
      mimeType: doc['mime_type'] as String? ?? 'application/json',
      url: doc['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sha256': sha256,
      'mime_type': mimeType,
      'url': url,
    };
  }

  @override
  List<Object?> get props => [id, sha256, mimeType, url];
}
