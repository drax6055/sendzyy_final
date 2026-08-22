import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import 'package:iFloraBuzz/features/chat/data/services/reply_context_store.dart';
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

class SetReplyMessage extends ChatEvent {
  final Map<String, dynamic>? message;
  SetReplyMessage(this.message);
  @override
  List<Object?> get props => [message];
}

class SendMessage extends ChatEvent {
  final String contactId;
  final String text;
  final String? replyToMessageId;
  final String? replyToWamid;
  SendMessage(this.contactId, this.text, {this.replyToMessageId, this.replyToWamid});
  @override
  List<Object?> get props => [contactId, text, replyToMessageId, replyToWamid];
}

class SendMediaMessage extends ChatEvent {
  final String contactId;
  final String mediaId;
  final String type;
  final String? filename;
  final String? replyToMessageId;
  final String? replyToWamid;

  SendMediaMessage({
    required this.contactId,
    required this.mediaId,
    required this.type,
    this.filename,
    this.replyToMessageId,
    this.replyToWamid,
  });

  @override
  List<Object?> get props => [contactId, mediaId, type, filename, replyToMessageId, replyToWamid];
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
  final Map<String, dynamic>? replyingToMessage;

  ChatLoaded({
    required this.conversations,
    this.selectedContactId,
    required this.messages,
    this.replyingToMessage,
  });

  @override
  List<Object?> get props => [conversations, selectedContactId, messages, replyingToMessage];

  ChatLoaded copyWith({
    List<Map<String, dynamic>>? conversations,
    String? selectedContactId,
    bool clearSelectedContact = false,
    List<Map<String, dynamic>>? messages,
    Map<String, dynamic>? replyingToMessage,
    bool clearReplyingToMessage = false,
  }) {
    return ChatLoaded(
      conversations: conversations ?? this.conversations,
      selectedContactId: clearSelectedContact ? null : (selectedContactId ?? this.selectedContactId),
      messages: messages ?? this.messages,
      replyingToMessage: clearReplyingToMessage ? null : (replyingToMessage ?? this.replyingToMessage),
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
    // Initialise the persistent reply context store
    ReplyContextStore.init();
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
            clearReplyingToMessage: true,
          ));
          return;
        }
        emit(currentState.copyWith(
          selectedContactId: event.contactId,
          messages: const [],
          clearReplyingToMessage: true,
        ));

        // Fetch existing messages via REST immediately
        final initial = await _repository.getMessages(event.contactId!);
        if (state is ChatLoaded) {
          final enriched = ReplyContextStore.enrich(initial);
          emit((state as ChatLoaded).copyWith(messages: enriched));
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
        final enriched = ReplyContextStore.enrich(event.messages);
        emit((state as ChatLoaded).copyWith(messages: enriched));
      }
    });

    on<SetReplyMessage>((event, emit) {
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(
          replyingToMessage: event.message,
          clearReplyingToMessage: event.message == null,
        ));
      }
    });

    on<SendMessage>((event, emit) async {
      final replyId = event.replyToMessageId ?? event.replyToWamid;
      // Register in pending store BEFORE sending so Socket.io update is enriched
      if (replyId != null && replyId.isNotEmpty) {
        ReplyContextStore.registerPending(
          messageText: event.text.trim(),
          contextMessageId: replyId,
        );
      }
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(clearReplyingToMessage: true));
      }
      try {
        final wamid = await _repository.sendFreeFormMessage(
          to: event.contactId,
          text: event.text,
          replyToMessageId: event.replyToMessageId,
          replyToWamid: event.replyToWamid,
        );
        // Promote pending to persistent wamid-keyed store
        if (replyId != null && replyId.isNotEmpty && wamid != null && wamid.isNotEmpty) {
          ReplyContextStore.confirmWamid(wamid: wamid, contextMessageId: replyId);
        }
      } catch (_) {}
    });

    on<SendMediaMessage>((event, emit) async {
      final replyId = event.replyToMessageId ?? event.replyToWamid;
      if (replyId != null && replyId.isNotEmpty) {
        ReplyContextStore.registerPending(
          messageText: (event.filename ?? event.type).trim(),
          contextMessageId: replyId,
        );
      }
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(clearReplyingToMessage: true));
      }
      try {
        final wamid = await _repository.sendDirectMediaMessage(
          to: event.contactId,
          mediaId: event.mediaId,
          type: event.type,
          filename: event.filename,
          replyToMessageId: event.replyToMessageId,
          replyToWamid: event.replyToWamid,
        );
        if (replyId != null && replyId.isNotEmpty && wamid != null && wamid.isNotEmpty) {
          ReplyContextStore.confirmWamid(wamid: wamid, contextMessageId: replyId);
        }
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
