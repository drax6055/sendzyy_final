import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/services/calling_webrtc_service.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';
import 'package:iFloraBuzz/features/calling/data/repositories/calling_repository.dart';

// --- Events ---
abstract class CallControlEvent extends Equatable {
  const CallControlEvent();
  @override
  List<Object?> get props => [];
}

class InitiateCallEvent extends CallControlEvent {
  final String phoneNumberId;
  final String to;
  final String? callerName;
  final bool enableRecording;
  final bool enableTranscription;
  final String? recordingPurpose;

  const InitiateCallEvent({
    required this.phoneNumberId,
    required this.to,
    this.callerName,
    this.enableRecording = false,
    this.enableTranscription = false,
    this.recordingPurpose,
  });

  @override
  List<Object?> get props => [phoneNumberId, to, callerName, enableRecording, enableTranscription, recordingPurpose];
}

class IncomingCallReceivedEvent extends CallControlEvent {
  final String phoneNumberId;
  final String callId;
  final String from;
  final String? callerName;
  final SdpSessionModel remoteOffer;

  const IncomingCallReceivedEvent({
    required this.phoneNumberId,
    required this.callId,
    required this.from,
    this.callerName,
    required this.remoteOffer,
  });

  @override
  List<Object?> get props => [phoneNumberId, callId, from, callerName, remoteOffer];
}

class AcceptCallEvent extends CallControlEvent {
  final bool enableRecording;
  final bool enableTranscription;
  final String? recordingPurpose;

  const AcceptCallEvent({
    this.enableRecording = false,
    this.enableTranscription = false,
    this.recordingPurpose,
  });

  @override
  List<Object?> get props => [enableRecording, enableTranscription, recordingPurpose];
}

class RejectCallEvent extends CallControlEvent {
  const RejectCallEvent();
}

class TerminateCallEvent extends CallControlEvent {
  const TerminateCallEvent();
}

class SendDTMFEvent extends CallControlEvent {
  final String digit;
  const SendDTMFEvent(this.digit);

  @override
  List<Object?> get props => [digit];
}

class ToggleMuteEvent extends CallControlEvent {
  const ToggleMuteEvent();
}

class ToggleSpeakerEvent extends CallControlEvent {
  const ToggleSpeakerEvent();
}

class CallWebhookEventReceived extends CallControlEvent {
  final Map<String, dynamic> payload;
  const CallWebhookEventReceived(this.payload);

  @override
  List<Object?> get props => [payload];
}

// --- States ---
abstract class CallControlState extends Equatable {
  const CallControlState();
  @override
  List<Object?> get props => [];
}

class CallIdle extends CallControlState {}

class CallConnectingState extends CallControlState {
  final String to;
  final String? callerName;
  const CallConnectingState({required this.to, this.callerName});

  @override
  List<Object?> get props => [to, callerName];
}

class CallIncomingState extends CallControlState {
  final String callId;
  final String from;
  final String? callerName;
  final SdpSessionModel remoteOffer;

  const CallIncomingState({
    required this.callId,
    required this.from,
    this.callerName,
    required this.remoteOffer,
  });

  @override
  List<Object?> get props => [callId, from, callerName, remoteOffer];
}

class CallRingingState extends CallControlState {
  final String callId;
  final String to;
  final String? callerName;

  const CallRingingState({
    required this.callId,
    required this.to,
    this.callerName,
  });

  @override
  List<Object?> get props => [callId, to, callerName];
}

class CallConnectedState extends CallControlState {
  final CallModel call;
  final bool isMuted;
  final bool isSpeaker;
  final int durationSeconds;

  const CallConnectedState({
    required this.call,
    this.isMuted = false,
    this.isSpeaker = false,
    this.durationSeconds = 0,
  });

  CallConnectedState copyWith({
    bool? isMuted,
    bool? isSpeaker,
    int? durationSeconds,
  }) {
    return CallConnectedState(
      call: call,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  List<Object?> get props => [call, isMuted, isSpeaker, durationSeconds];
}

class CallTerminatedState extends CallControlState {
  final String callId;
  final String reason;
  final int durationSeconds;

  const CallTerminatedState({
    required this.callId,
    required this.reason,
    this.durationSeconds = 0,
  });

  @override
  List<Object?> get props => [callId, reason, durationSeconds];
}

class CallErrorState extends CallControlState {
  final String message;
  const CallErrorState(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CallControlBloc extends Bloc<CallControlEvent, CallControlState> {
  final CallingRepository _repository;
  final CallingWebRTCService _webrtcService;

  Timer? _callTimer;
  int _timerSeconds = 0;
  String _activePhoneNumberId = '';
  String _activeCallId = '';
  CallModel? _activeCallModel;

  CallControlBloc({
    required CallingRepository repository,
    required CallingWebRTCService webrtcService,
  })  : _repository = repository,
        _webrtcService = webrtcService,
        super(CallIdle()) {
    on<InitiateCallEvent>(_onInitiateCall);
    on<IncomingCallReceivedEvent>(_onIncomingCallReceived);
    on<AcceptCallEvent>(_onAcceptCall);
    on<RejectCallEvent>(_onRejectCall);
    on<TerminateCallEvent>(_onTerminateCall);
    on<SendDTMFEvent>(_onSendDTMF);
    on<ToggleMuteEvent>(_onToggleMute);
    on<ToggleSpeakerEvent>(_onToggleSpeaker);
    on<CallWebhookEventReceived>(_onCallWebhookReceived);
  }

  Future<void> _onInitiateCall(
    InitiateCallEvent event,
    Emitter<CallControlState> emit,
  ) async {
    try {
      emit(CallConnectingState(to: event.to, callerName: event.callerName));
      _activePhoneNumberId = event.phoneNumberId;

      await _webrtcService.initialize();
      final localOffer = await _webrtcService.createOffer();

      final call = await _repository.initiateCall(
        phoneNumberId: event.phoneNumberId,
        to: event.to,
        session: localOffer,
        enableRecording: event.enableRecording,
        enableTranscription: event.enableTranscription,
        recordingPurpose: event.recordingPurpose,
      );

      _activeCallId = call.callId;
      _activeCallModel = call;

      emit(CallRingingState(
        callId: call.callId,
        to: event.to,
        callerName: event.callerName,
      ));
    } catch (e) {
      await _webrtcService.disposeSession();
      emit(CallErrorState('Failed to initiate call: $e'));
    }
  }

  void _onIncomingCallReceived(
    IncomingCallReceivedEvent event,
    Emitter<CallControlState> emit,
  ) {
    _activePhoneNumberId = event.phoneNumberId;
    _activeCallId = event.callId;
    emit(CallIncomingState(
      callId: event.callId,
      from: event.from,
      callerName: event.callerName,
      remoteOffer: event.remoteOffer,
    ));
  }

  Future<void> _onAcceptCall(
    AcceptCallEvent event,
    Emitter<CallControlState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CallIncomingState) return;

    try {
      await _webrtcService.initialize();
      await _webrtcService.setRemoteDescription(currentState.remoteOffer);

      // Pre-accept call first to avoid audio clipping
      final localAnswer = await _webrtcService.createAnswer();
      await _repository.preAcceptCall(
        phoneNumberId: _activePhoneNumberId,
        callId: currentState.callId,
        session: localAnswer,
      );

      // Accept call
      await _repository.acceptCall(
        phoneNumberId: _activePhoneNumberId,
        callId: currentState.callId,
        session: localAnswer,
        enableRecording: event.enableRecording,
        enableTranscription: event.enableTranscription,
        recordingPurpose: event.recordingPurpose,
      );

      _startTimer(emit);

      _activeCallModel = CallModel(
        callId: currentState.callId,
        to: _activePhoneNumberId,
        from: currentState.from,
        callerName: currentState.callerName,
        direction: CallDirection.userInitiated,
        status: CallStatus.accepted,
        timestamp: DateTime.now(),
        startTime: DateTime.now(),
      );

      emit(CallConnectedState(call: _activeCallModel!));
    } catch (e) {
      await _webrtcService.disposeSession();
      emit(CallErrorState('Failed to accept call: $e'));
    }
  }

  Future<void> _onRejectCall(
    RejectCallEvent event,
    Emitter<CallControlState> emit,
  ) async {
    try {
      if (_activeCallId.isNotEmpty) {
        await _repository.rejectCall(
          phoneNumberId: _activePhoneNumberId,
          callId: _activeCallId,
        );
      }
    } catch (_) {}
    await _webrtcService.disposeSession();
    emit(CallIdle());
  }

  Future<void> _onTerminateCall(
    TerminateCallEvent event,
    Emitter<CallControlState> emit,
  ) async {
    _stopTimer();
    try {
      if (_activeCallId.isNotEmpty) {
        await _repository.terminateCall(
          phoneNumberId: _activePhoneNumberId,
          callId: _activeCallId,
        );
      }
    } catch (_) {}

    final duration = _timerSeconds;
    await _webrtcService.disposeSession();
    emit(CallTerminatedState(
      callId: _activeCallId,
      reason: 'Call Ended',
      durationSeconds: duration,
    ));
  }

  Future<void> _onSendDTMF(
    SendDTMFEvent event,
    Emitter<CallControlState> emit,
  ) async {
    await _webrtcService.sendDTMF(event.digit);
  }

  Future<void> _onToggleMute(
    ToggleMuteEvent event,
    Emitter<CallControlState> emit,
  ) async {
    final currentState = state;
    if (currentState is CallConnectedState) {
      final newMuted = !currentState.isMuted;
      await _webrtcService.setMicrophoneMuted(newMuted);
      emit(currentState.copyWith(isMuted: newMuted));
    }
  }

  Future<void> _onToggleSpeaker(
    ToggleSpeakerEvent event,
    Emitter<CallControlState> emit,
  ) async {
    final currentState = state;
    if (currentState is CallConnectedState) {
      final newSpeaker = !currentState.isSpeaker;
      await _webrtcService.setSpeakerphoneOn(newSpeaker);
      emit(currentState.copyWith(isSpeaker: newSpeaker));
    }
  }

  Future<void> _onCallWebhookReceived(
    CallWebhookEventReceived event,
    Emitter<CallControlState> emit,
  ) async {
    final payload = event.payload;
    final eventName = payload['event'] as String?;
    final sdpObj = payload['session'] as Map<String, dynamic>?;

    if (eventName == 'connect' && sdpObj != null) {
      final sdpAnswer = SdpSessionModel.fromJson(sdpObj);
      await _webrtcService.setRemoteDescription(sdpAnswer);

      _startTimer(emit);
      if (_activeCallModel != null) {
        _activeCallModel = _activeCallModel!.copyWith(
          status: CallStatus.accepted,
          startTime: DateTime.now(),
        );
        emit(CallConnectedState(call: _activeCallModel!));
      }
    } else if (eventName == 'terminate') {
      _stopTimer();
      await _webrtcService.disposeSession();
      final durationStr = payload['duration']?.toString() ?? '0';
      final duration = int.tryParse(durationStr) ?? _timerSeconds;
      emit(CallTerminatedState(
        callId: payload['id'] as String? ?? _activeCallId,
        reason: 'Terminated by Meta/Remote User',
        durationSeconds: duration,
      ));
    }
  }

  void _startTimer(Emitter<CallControlState> emit) {
    _stopTimer();
    _timerSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerSeconds++;
      if (state is CallConnectedState) {
        final current = state as CallConnectedState;
        emit(current.copyWith(durationSeconds: _timerSeconds));
      }
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  @override
  Future<void> close() {
    _stopTimer();
    _webrtcService.disposeSession();
    return super.close();
  }
}
