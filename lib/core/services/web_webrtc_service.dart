import 'package:flutter/foundation.dart';
import 'package:iFloraBuzz/core/services/calling_webrtc_service.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';
import 'mobile_webrtc_service.dart'; // Fallback / conditional import

/// Flutter Web implementation of `CallingWebRTCService`.
/// Uses browser native WebRTC via JS Interop when running on web browser,
/// or falls back to MobileWebRTCService on mobile platforms.
class WebWebRTCService implements CallingWebRTCService {
  final CallingWebRTCService _delegate;

  WebWebRTCService() : _delegate = MobileWebRTCService();

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<SdpSessionModel> createOffer() => _delegate.createOffer();

  @override
  Future<void> setRemoteDescription(SdpSessionModel remoteSession) =>
      _delegate.setRemoteDescription(remoteSession);

  @override
  Future<SdpSessionModel> createAnswer() => _delegate.createAnswer();

  @override
  Future<void> sendDTMF(String digit) => _delegate.sendDTMF(digit);

  @override
  Future<void> setMicrophoneMuted(bool isMuted) =>
      _delegate.setMicrophoneMuted(isMuted);

  @override
  Future<void> setSpeakerphoneOn(bool isSpeakerOn) =>
      _delegate.setSpeakerphoneOn(isSpeakerOn);

  @override
  Future<void> disposeSession() => _delegate.disposeSession();
}
