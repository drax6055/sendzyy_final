import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';

// --- Events ---
abstract class CallLogEvent extends Equatable {
  const CallLogEvent();
  @override
  List<Object?> get props => [];
}

class LoadCallLogEvent extends CallLogEvent {}

class AddCallToLogEvent extends CallLogEvent {
  final CallModel call;
  const AddCallToLogEvent(this.call);

  @override
  List<Object?> get props => [call];
}

class ClearCallLogEvent extends CallLogEvent {}

// --- States ---
abstract class CallLogState extends Equatable {
  const CallLogState();
  @override
  List<Object?> get props => [];
}

class CallLogInitial extends CallLogState {}

class CallLogLoading extends CallLogState {}

class CallLogLoaded extends CallLogState {
  final List<CallModel> calls;
  const CallLogLoaded(this.calls);

  @override
  List<Object?> get props => [calls];
}

class CallLogError extends CallLogState {
  final String message;
  const CallLogError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CallLogBloc extends Bloc<CallLogEvent, CallLogState> {
  final List<CallModel> _inMemoryLogs = [];

  CallLogBloc() : super(CallLogInitial()) {
    on<LoadCallLogEvent>((event, emit) {
      emit(CallLogLoading());
      emit(CallLogLoaded(List.unmodifiable(_inMemoryLogs)));
    });

    on<AddCallToLogEvent>((event, emit) {
      _inMemoryLogs.insert(0, event.call);
      emit(CallLogLoaded(List.unmodifiable(_inMemoryLogs)));
    });

    on<ClearCallLogEvent>((event, emit) {
      _inMemoryLogs.clear();
      emit(const CallLogLoaded([]));
    });
  }
}
