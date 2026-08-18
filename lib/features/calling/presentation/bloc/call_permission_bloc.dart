import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_permission_model.dart';
import 'package:iFloraBuzz/features/calling/data/repositories/calling_repository.dart';

// --- Events ---
abstract class CallPermissionEvent extends Equatable {
  const CallPermissionEvent();
  @override
  List<Object?> get props => [];
}

class CheckCallPermissionEvent extends CallPermissionEvent {
  final String phoneNumberId;
  final String? userWaId;
  final String? recipientBsuid;

  const CheckCallPermissionEvent({
    required this.phoneNumberId,
    this.userWaId,
    this.recipientBsuid,
  });

  @override
  List<Object?> get props => [phoneNumberId, userWaId, recipientBsuid];
}

class SendCallPermissionRequestEvent extends CallPermissionEvent {
  final String phoneNumberId;
  final String to;
  final String? bodyText;
  final String? recipientBsuid;

  const SendCallPermissionRequestEvent({
    required this.phoneNumberId,
    required this.to,
    this.bodyText,
    this.recipientBsuid,
  });

  @override
  List<Object?> get props => [phoneNumberId, to, bodyText, recipientBsuid];
}

class PermissionWebhookReceivedEvent extends CallPermissionEvent {
  final Map<String, dynamic> payload;
  const PermissionWebhookReceivedEvent(this.payload);

  @override
  List<Object?> get props => [payload];
}

// --- States ---
abstract class CallPermissionState extends Equatable {
  const CallPermissionState();
  @override
  List<Object?> get props => [];
}

class CallPermissionInitial extends CallPermissionState {}

class CallPermissionLoading extends CallPermissionState {}

class CallPermissionLoaded extends CallPermissionState {
  final CallPermissionModel permission;
  final String? lastMessageId;
  final String? statusMessage;

  const CallPermissionLoaded({
    required this.permission,
    this.lastMessageId,
    this.statusMessage,
  });

  @override
  List<Object?> get props => [permission, lastMessageId, statusMessage];
}

class CallPermissionError extends CallPermissionState {
  final String message;
  const CallPermissionError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CallPermissionBloc extends Bloc<CallPermissionEvent, CallPermissionState> {
  final CallingRepository _repository;

  CallPermissionBloc(this._repository) : super(CallPermissionInitial()) {
    on<CheckCallPermissionEvent>(_onCheckPermission);
    on<SendCallPermissionRequestEvent>(_onSendPermissionRequest);
    on<PermissionWebhookReceivedEvent>(_onWebhookReceived);
  }

  Future<void> _onCheckPermission(
    CheckCallPermissionEvent event,
    Emitter<CallPermissionState> emit,
  ) async {
    emit(CallPermissionLoading());
    try {
      final permission = await _repository.getCallPermission(
        phoneNumberId: event.phoneNumberId,
        userWaId: event.userWaId,
        recipientBsuid: event.recipientBsuid,
      );
      emit(CallPermissionLoaded(permission: permission));
    } catch (e) {
      emit(CallPermissionError('Failed to check permission: $e'));
    }
  }

  Future<void> _onSendPermissionRequest(
    SendCallPermissionRequestEvent event,
    Emitter<CallPermissionState> emit,
  ) async {
    final currentPerm = state is CallPermissionLoaded
        ? (state as CallPermissionLoaded).permission
        : null;
    emit(CallPermissionLoading());
    try {
      final msgId = await _repository.sendCallPermissionRequest(
        phoneNumberId: event.phoneNumberId,
        to: event.to,
        bodyText: event.bodyText,
        recipientBsuid: event.recipientBsuid,
      );

      if (currentPerm != null) {
        emit(CallPermissionLoaded(
          permission: currentPerm,
          lastMessageId: msgId,
          statusMessage: 'Permission request sent successfully',
        ));
      } else {
        // Re-check after sending
        final updated = await _repository.getCallPermission(
          phoneNumberId: event.phoneNumberId,
          userWaId: event.to,
          recipientBsuid: event.recipientBsuid,
        );
        emit(CallPermissionLoaded(
          permission: updated,
          lastMessageId: msgId,
          statusMessage: 'Permission request sent successfully',
        ));
      }
    } catch (e) {
      emit(CallPermissionError('Failed to send permission request: $e'));
    }
  }

  void _onWebhookReceived(
    PermissionWebhookReceivedEvent event,
    Emitter<CallPermissionState> emit,
  ) {
    final reply = event.payload['call_permission_reply'] as Map<String, dynamic>?;
    if (reply != null) {
      final response = reply['response'] as String? ?? '';
      final isPermanent = reply['is_permanent'] as bool? ?? false;
      final expSecStr = reply['expiration_timestamp']?.toString();
      final expSec = expSecStr != null ? int.tryParse(expSecStr) : null;

      PermissionStatusState stateVal;
      if (response == 'accept') {
        stateVal = isPermanent
            ? PermissionStatusState.permanent
            : PermissionStatusState.temporary;
      } else {
        stateVal = PermissionStatusState.noPermission;
      }

      final expTime = expSec != null
          ? DateTime.fromMillisecondsSinceEpoch(expSec * 1000)
          : null;

      final model = CallPermissionModel(
        status: stateVal,
        expirationTime: expTime,
        actions: const [],
      );

      emit(CallPermissionLoaded(
        permission: model,
        statusMessage: 'Permission status updated via webhook: ${stateVal.name}',
      ));
    }
  }
}
