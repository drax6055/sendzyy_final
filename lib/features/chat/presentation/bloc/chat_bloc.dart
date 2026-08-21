import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import 'package:file_picker/file_picker.dart';

// Events
abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchConversations extends ChatEvent {}

class UpdateConversations extends ChatEvent {
  final List<Map<String, dynamic>> conversations;
  UpdateConversations(this.conversations);
  @override
  List<Object?> get props => [conversations];
}

class SelectConversation extends ChatEvent {
  final String? contactId;
  SelectConversation(this.contactId);
  @override
  List<Object?> get props => [contactId];
}

class UpdateMessages extends ChatEvent {
  final List<Map<String, dynamic>> messages;
  UpdateMessages(this.messages);
  @override
  List<Object?> get props => [messages];
}

class SendMessage extends ChatEvent {
  final String contactId;
  final String text;
  SendMessage(this.contactId, this.text);
  @override
  List<Object?> get props => [contactId, text];
}

class SendMediaMessage extends ChatEvent {
  final String contactId;
  final String mediaId;
  final String type;
  final String? filename;

  SendMediaMessage({
    required this.contactId,
    required this.mediaId,
    required this.type,
    this.filename,
  });

  @override
  List<Object?> get props => [contactId, mediaId, type, filename];
}

// States
abstract class ChatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Map<String, dynamic>> conversations;
  final String? selectedContactId;
  final List<Map<String, dynamic>> messages;

  ChatLoaded({
    required this.conversations,
    this.selectedContactId,
    required this.messages,
  });

  @override
  List<Object?> get props => [conversations, selectedContactId, messages];

  ChatLoaded copyWith({
    List<Map<String, dynamic>>? conversations,
    String? selectedContactId,
    bool clearSelectedContact = false,
    List<Map<String, dynamic>>? messages,
  }) {
    return ChatLoaded(
      conversations: conversations ?? this.conversations,
      selectedContactId: clearSelectedContact ? null : (selectedContactId ?? this.selectedContactId),
      messages: messages ?? this.messages,
    );
  }
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final WhatsAppRepository _repository;
  final SocketService _socketService;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  ChatBloc(this._repository, this._socketService) : super(ChatInitial()) {
    on<FetchConversations>((event, emit) async {
      final tenantId = _repository.tenantId;
      if (tenantId == null) {
        emit(ChatError('Not authenticated'));
        return;
      }
      emit(ChatLoading());

      // Fetch existing conversations via REST immediately so UI doesn't hang
      final initial = await _repository.getConversations();
      emit(ChatLoaded(conversations: initial, messages: const []));

      // Subscribe to socket for live updates
      _conversationsSubscription?.cancel();
      _conversationsSubscription =
          _socketService.getConversations().listen((convs) {
        add(UpdateConversations(convs));
      });
    });

    on<UpdateConversations>((event, emit) {
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(conversations: event.conversations));
      } else {
        emit(ChatLoaded(conversations: event.conversations, messages: const []));
      }
    });

    on<SelectConversation>((event, emit) async {
      if (state is ChatLoaded) {
        final currentState = state as ChatLoaded;
        if (event.contactId == null) {
          _messagesSubscription?.cancel();
          emit(currentState.copyWith(
            clearSelectedContact: true,
            messages: const [],
          ));
          return;
        }
        emit(currentState.copyWith(
          selectedContactId: event.contactId,
          messages: const [],
        ));

        // Fetch existing messages via REST immediately
        final initial = await _repository.getMessages(event.contactId!);
        if (state is ChatLoaded) {
          emit((state as ChatLoaded).copyWith(messages: initial));
        }

        // Subscribe to socket for live updates
        _messagesSubscription?.cancel();
        _messagesSubscription =
            _socketService.getMessages(event.contactId!).listen((messages) {
          add(UpdateMessages(messages));
        });
      }
    });

    on<UpdateMessages>((event, emit) {
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(messages: event.messages));
      }
    });

    on<SendMessage>((event, emit) async {
      try {
        await _repository.sendFreeFormMessage(
          to: event.contactId,
          text: event.text,
        );
      } catch (_) {}
    });

    on<SendMediaMessage>((event, emit) async {
      try {
        await _repository.sendDirectMediaMessage(
          to: event.contactId,
          mediaId: event.mediaId,
          type: event.type,
          filename: event.filename,
        );
      } catch (_) {}
    });
  }

  @override
  Future<void> close() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }

  /// Returns the JWT auth token for authenticated media requests.
  String? get authToken => _repository.authToken;

  /// Returns the full proxy URL for a WhatsApp media file by its mediaId.
  String? getMediaUrl(String mediaId) => _repository.getMediaUrl(mediaId);

  /// Uploads media to Meta via the repository proxy.
  Future<String> uploadMedia(PlatformFile file) => _repository.uploadMedia(file);
}
