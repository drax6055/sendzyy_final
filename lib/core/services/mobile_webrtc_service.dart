import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:iFloraBuzz/core/services/calling_webrtc_service.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';

/// Mobile (Android & iOS) implementation using `flutter_webrtc`.
class MobileWebRTCService implements CallingWebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCDTMFSender? _dtmfSender;
  bool _isMuted = false;
  bool _isSpeaker = false;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _offerAnswerConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  @override
  Future<void> initialize() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      } catch (fallbackErr) {
        throw Exception('No microphone device detected on your system. Please connect a microphone or headset to make voice calls.');
      }
    }

    _peerConnection = await createPeerConnection(_configuration, _offerAnswerConstraints);

    for (final track in _localStream!.getAudioTracks()) {
      final rtpSender = await _peerConnection!.addTrack(track, _localStream!);
      if (rtpSender.dtmfSender != null) {
        _dtmfSender = rtpSender.dtmfSender;
      }
    }
  }

  @override
  Future<SdpSessionModel> createOffer() async {
    if (_peerConnection == null) await initialize();
    final description = await _peerConnection!.createOffer(_offerAnswerConstraints);
    await _peerConnection!.setLocalDescription(description);
    return SdpSessionModel(
      sdpType: 'offer',
      sdp: description.sdp ?? '',
    );
  }

  @override
  Future<void> setRemoteDescription(SdpSessionModel remoteSession) async {
    if (_peerConnection == null) await initialize();
    final description = RTCSessionDescription(
      remoteSession.sdp,
      remoteSession.sdpType,
    );
    await _peerConnection!.setRemoteDescription(description);
  }

  @override
  Future<SdpSessionModel> createAnswer() async {
    if (_peerConnection == null) await initialize();
    final description = await _peerConnection!.createAnswer(_offerAnswerConstraints);
    await _peerConnection!.setLocalDescription(description);
    return SdpSessionModel(
      sdpType: 'answer',
      sdp: description.sdp ?? '',
    );
  }

  @override
  Future<void> sendDTMF(String digit) async {
    if (_dtmfSender != null) {
      await _dtmfSender!.insertDTMF(digit, duration: 200, interToneGap: 50);
    } else {
      debugPrint('[MobileWebRTCService] DTMF sender not available');
    }
  }

  @override
  Future<void> setMicrophoneMuted(bool isMuted) async {
    _isMuted = isMuted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
  }

  @override
  Future<void> setSpeakerphoneOn(bool isSpeakerOn) async {
    _isSpeaker = isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeaker);
    } catch (e) {
      debugPrint('[MobileWebRTCService] Error toggling speakerphone: $e');
    }
  }

  @override
  Future<void> disposeSession() async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }
  }
}
