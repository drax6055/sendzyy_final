import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_settings_model.dart';
import 'package:iFloraBuzz/features/calling/data/repositories/calling_repository.dart';

// --- Events ---
abstract class CallSettingsEvent extends Equatable {
  const CallSettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoadCallSettingsEvent extends CallSettingsEvent {
  final String phoneNumberId;
  const LoadCallSettingsEvent(this.phoneNumberId);

  @override
  List<Object?> get props => [phoneNumberId];
}

class UpdateCallSettingsEvent extends CallSettingsEvent {
  final String phoneNumberId;
  final CallSettingsModel settings;

  const UpdateCallSettingsEvent({
    required this.phoneNumberId,
    required this.settings,
  });

  @override
  List<Object?> get props => [phoneNumberId, settings];
}

// --- States ---
abstract class CallSettingsState extends Equatable {
  const CallSettingsState();
  @override
  List<Object?> get props => [];
}

class CallSettingsInitial extends CallSettingsState {}

class CallSettingsLoading extends CallSettingsState {}

class CallSettingsLoaded extends CallSettingsState {
  final CallSettingsModel settings;
  final String? successMessage;

  const CallSettingsLoaded({required this.settings, this.successMessage});

  @override
  List<Object?> get props => [settings, successMessage];
}

class CallSettingsError extends CallSettingsState {
  final String message;
  const CallSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CallSettingsBloc extends Bloc<CallSettingsEvent, CallSettingsState> {
  final CallingRepository _repository;

  CallSettingsBloc(this._repository) : super(CallSettingsInitial()) {
    on<LoadCallSettingsEvent>(_onLoadSettings);
    on<UpdateCallSettingsEvent>(_onUpdateSettings);
  }

  Future<void> _onLoadSettings(
    LoadCallSettingsEvent event,
    Emitter<CallSettingsState> emit,
  ) async {
    emit(CallSettingsLoading());
    try {
      final settings = await _repository.getCallSettings(event.phoneNumberId);
      emit(CallSettingsLoaded(settings: settings));
    } catch (e) {
      emit(CallSettingsError('Failed to load call settings: $e'));
    }
  }

  Future<void> _onUpdateSettings(
    UpdateCallSettingsEvent event,
    Emitter<CallSettingsState> emit,
  ) async {
    emit(CallSettingsLoading());
    try {
      final success = await _repository.updateCallSettings(
        phoneNumberId: event.phoneNumberId,
        settings: event.settings,
      );
      if (success) {
        emit(CallSettingsLoaded(
          settings: event.settings,
          successMessage: 'Call settings updated successfully',
        ));
      } else {
        emit(const CallSettingsError('Failed to update call settings'));
      }
    } catch (e) {
      emit(CallSettingsError('Error updating call settings: $e'));
    }
  }
}
