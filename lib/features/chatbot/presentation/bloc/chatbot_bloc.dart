import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/chatbot_model.dart';
import 'package:iFloraBuzz/features/chatbot/data/repositories/chatbot_repository.dart';

// Events
abstract class ChatbotEvent {}

class LoadChatbots extends ChatbotEvent {}

class CreateChatbot extends ChatbotEvent {
  final String name;
  final List<String> keywords;
  final Map<String, dynamic> flow;

  CreateChatbot({required this.name, required this.keywords, required this.flow});
}

class UpdateChatbot extends ChatbotEvent {
  final String id;
  final Map<String, dynamic> fields;

  UpdateChatbot({required this.id, required this.fields});
}

class DeleteChatbot extends ChatbotEvent {
  final String id;
  DeleteChatbot(this.id);
}

class ToggleChatbotActive extends ChatbotEvent {
  final String id;
  final bool isActive;

  ToggleChatbotActive({required this.id, required this.isActive});
}

class LoadChatbotAnalytics extends ChatbotEvent {
  final String chatbotId;
  LoadChatbotAnalytics(this.chatbotId);
}

// States
abstract class ChatbotState {}

class ChatbotInitial extends ChatbotState {}

class ChatbotLoading extends ChatbotState {}

class ChatbotLoaded extends ChatbotState {
  final List<ChatbotModel> chatbots;
  final bool deletedSuccessfully;
  final String? analyticsLoadingId;
  final String? analyticsLoadedId;
  final List<DailyAnalytics> analytics;

  ChatbotLoaded(
    this.chatbots, {
    this.deletedSuccessfully = false,
    this.analyticsLoadingId,
    this.analyticsLoadedId,
    this.analytics = const [],
  });
}

class ChatbotError extends ChatbotState {
  final String message;
  ChatbotError(this.message);
}

// Bloc
class ChatbotBloc extends Bloc<ChatbotEvent, ChatbotState> {
  final ChatbotRepository _repository;

  ChatbotBloc(this._repository) : super(ChatbotInitial()) {
    on<LoadChatbots>(_onLoadChatbots);
    on<CreateChatbot>(_onCreateChatbot);
    on<UpdateChatbot>(_onUpdateChatbot);
    on<DeleteChatbot>(_onDeleteChatbot);
    on<ToggleChatbotActive>(_onToggleChatbotActive);
    on<LoadChatbotAnalytics>(_onLoadChatbotAnalytics);
  }

  Future<void> _onLoadChatbots(
    LoadChatbots event,
    Emitter<ChatbotState> emit,
  ) async {
    emit(ChatbotLoading());
    try {
      final chatbots = await _repository.fetchAll();
      emit(ChatbotLoaded(chatbots));
    } catch (e) {
      emit(ChatbotError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateChatbot(
    CreateChatbot event,
    Emitter<ChatbotState> emit,
  ) async {
    final current = state is ChatbotLoaded ? (state as ChatbotLoaded).chatbots : <ChatbotModel>[];
    emit(ChatbotLoading());
    try {
      final created = await _repository.create(event.name, event.keywords, event.flow);
      emit(ChatbotLoaded([created, ...current]));
    } catch (e) {
      emit(ChatbotError(e.toString().replaceAll('Exception: ', '')));
      if (current.isNotEmpty) emit(ChatbotLoaded(current));
    }
  }

  Future<void> _onUpdateChatbot(
    UpdateChatbot event,
    Emitter<ChatbotState> emit,
  ) async {
    final current = state is ChatbotLoaded ? (state as ChatbotLoaded).chatbots : <ChatbotModel>[];
    try {
      final updated = await _repository.update(event.id, event.fields);
      final updatedList = current.map((c) => c.id == event.id ? updated : c).toList();
      emit(ChatbotLoaded(updatedList));
    } catch (e) {
      emit(ChatbotError(e.toString().replaceAll('Exception: ', '')));
      if (current.isNotEmpty) emit(ChatbotLoaded(current));
    }
  }

  Future<void> _onDeleteChatbot(
    DeleteChatbot event,
    Emitter<ChatbotState> emit,
  ) async {
    final current = state is ChatbotLoaded ? (state as ChatbotLoaded).chatbots : <ChatbotModel>[];
    try {
      await _repository.delete(event.id);
      emit(ChatbotLoaded(
        current.where((c) => c.id != event.id).toList(),
        deletedSuccessfully: true,
      ));
    } catch (e) {
      emit(ChatbotError(e.toString().replaceAll('Exception: ', '')));
      if (current.isNotEmpty) emit(ChatbotLoaded(current));
    }
  }

  Future<void> _onToggleChatbotActive(
    ToggleChatbotActive event,
    Emitter<ChatbotState> emit,
  ) async {
    final current = state is ChatbotLoaded ? (state as ChatbotLoaded).chatbots : <ChatbotModel>[];
    try {
      final updated = await _repository.toggleActive(event.id, event.isActive);
      final updatedList = current.map((c) => c.id == event.id ? updated : c).toList();
      emit(ChatbotLoaded(updatedList));
    } catch (e) {
      emit(ChatbotError(e.toString().replaceAll('Exception: ', '')));
      if (current.isNotEmpty) emit(ChatbotLoaded(current));
    }
  }

  Future<void> _onLoadChatbotAnalytics(
    LoadChatbotAnalytics event,
    Emitter<ChatbotState> emit,
  ) async {
    final current = state is ChatbotLoaded ? state as ChatbotLoaded : null;
    if (current == null) return;
    // Signal loading for this specific chatbot
    emit(ChatbotLoaded(current.chatbots, analyticsLoadingId: event.chatbotId));
    try {
      final analytics = await _repository.fetchAnalytics(event.chatbotId);
      emit(ChatbotLoaded(
        current.chatbots,
        analyticsLoadedId: event.chatbotId,
        analytics: analytics,
      ));
    } catch (_) {
      // Restore list without analytics loading indicator
      emit(ChatbotLoaded(current.chatbots));
    }
  }
}
