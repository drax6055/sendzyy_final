import 'package:flutter/foundation.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';
import 'mobile_webrtc_service.dart';
import 'web_webrtc_service.dart';

/// Abstract contract for real-time WebRTC audio sessions.
/// Implemented natively via `flutter_webrtc` on Android/iOS and via Browser JS Interop on Flutter Web.
abstract class CallingWebRTCService {
  /// Initialize audio stream and peer connection.
  Future<void> initialize();

  /// Create WebRTC SDP offer string for business-initiated calls.
  Future<SdpSessionModel> createOffer();

  /// Set remote SDP answer/offer received from Meta Cloud API.
  Future<void> setRemoteDescription(SdpSessionModel remoteSession);

  /// Create WebRTC SDP answer string in response to Meta's SDP offer.
  Future<SdpSessionModel> createAnswer();

  /// Send DTMF digit (0-9, *, #) over the active WebRTC stream.
  Future<void> sendDTMF(String digit);

  /// Mute/unmute microphone.
  Future<void> setMicrophoneMuted(bool isMuted);

  /// Toggle speakerphone vs earpiece.
  Future<void> setSpeakerphoneOn(bool isSpeakerOn);

  /// Hangup active WebRTC session and release audio tracks.
  Future<void> disposeSession();

  /// Factory constructor returning platform-specific implementation.
  factory CallingWebRTCService.create() {
    if (kIsWeb) {
      return WebWebRTCService();
    } else {
      return MobileWebRTCService();
    }
  }
}
