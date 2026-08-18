import 'package:equatable/equatable.dart';

/// Models the Session Description Protocol (SDP) session object for WebRTC negotiation.
class SdpSessionModel extends Equatable {
  final String sdpType; // 'offer' or 'answer'
  final String sdp;     // RFC 8866 SDP text

  const SdpSessionModel({
    required this.sdpType,
    required this.sdp,
  });

  factory SdpSessionModel.fromJson(Map<String, dynamic> json) {
    return SdpSessionModel(
      sdpType: json['sdp_type'] as String? ?? 'offer',
      sdp: json['sdp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sdp_type': sdpType,
      'sdp': sdp,
    };
  }

  @override
  List<Object?> get props => [sdpType, sdp];
}
