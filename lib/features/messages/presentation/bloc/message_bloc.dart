import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/messages/data/models/recipient_data.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';

// Events
abstract class MessageEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class SendBulkMessages extends MessageEvent {
  final List<RecipientData> recipients;
  final String template;
  final String language;
  final String? mediaId;
  final String? mediaType;

  SendBulkMessages(
    this.recipients,
    this.template,
    this.language, {
    this.mediaId,
    this.mediaType,
  });

  @override
  List<Object> get props => [recipients, template, language, mediaId ?? '', mediaType ?? ''];
}

// States
abstract class MessageState extends Equatable {
  @override
  List<Object> get props => [];
}

class MessageInitial extends MessageState {}

class MessageSending extends MessageState {
  final int sentCount;
  final int totalCount;
  MessageSending(this.sentCount, this.totalCount);
  @override
  List<Object> get props => [sentCount, totalCount];
}

class MessageSent extends MessageState {
  final int successCount;
  final int failureCount;
  final String campaignId;
  final DateTime? dispatchedAt;
  MessageSent(this.successCount, this.failureCount, this.campaignId, {this.dispatchedAt});
  @override
  List<Object> get props => [successCount, failureCount, campaignId, if (dispatchedAt != null) dispatchedAt!];
}

class MessageError extends MessageState {
  final String message;
  MessageError(this.message);
  @override
  List<Object> get props => [message];
}

// BLoC
class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final WhatsAppRepository _repository;

  MessageBloc(this._repository) : super(MessageInitial()) {
    on<SendBulkMessages>((event, emit) async {
      int total = event.recipients.length;
      int success = 0;
      int failure = 0;
      DateTime? dispatchedAt;

      final String campaignId = DateTime.now().millisecondsSinceEpoch.toString();

      try {
        for (int i = 0; i < total; i++) {
          emit(MessageSending(i + 1, total));

          final recipient = event.recipients[i];

          final String? wamid = await _repository.sendMessage(
            to: recipient.mobileNumber,
            templateName: event.template,
            languageCode: event.language,
            mediaId: event.mediaId,
            mediaType: event.mediaType,
            campaignId: campaignId,
            variables: recipient.variables,
          );

          if (wamid != null) {
            if (success == 0) dispatchedAt = DateTime.now();
            success++;
          } else {
            failure++;
          }
        }

        // Trigger phase 1 completion before emitting the final state so the
        // call executes while the bloc is still alive. If the bloc is disposed
        // after emit (widget navigates away), the await would never run.
        // Requirements: 2.4, 2.5, 3.1
        try {
          await _repository.completePhase1(campaignId);
        } catch (e) {
          debugPrint('[MessageBloc] completePhase1 failed: $e');
        }

        emit(MessageSent(success, failure, campaignId, dispatchedAt: dispatchedAt));
      } catch (e) {
        emit(MessageError('Campaign error: $e'));
      }
    });
  }
}

