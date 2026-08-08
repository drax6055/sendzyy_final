import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';

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
  /// Shared header text variable values for every recipient (e.g. {1: 'Hello'}).
  /// Per-recipient header variables are carried inside each [RecipientData.headerVariables].
  final Map<int, String>? headerVariables;

  SendBulkMessages(
    this.recipients,
    this.template,
    this.language, {
    this.mediaId,
    this.mediaType,
    this.headerVariables,
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
        const int batchSize = 10;
        int processedCount = 0;

        for (int i = 0; i < total; i += batchSize) {
          final chunk = event.recipients.sublist(
            i,
            (i + batchSize > total) ? total : i + batchSize,
          );

          final results = await Future.wait(chunk.map((recipient) async {
            final Map<int, String> effectiveHeaderVars = {
              ...?event.headerVariables,
              ...recipient.headerVariables,
            };

            try {
              return await _repository.sendMessage(
                to: recipient.mobileNumber,
                templateName: event.template,
                languageCode: event.language,
                mediaId: event.mediaId,
                mediaType: event.mediaType,
                campaignId: campaignId,
                variables: recipient.variables,
                headerVariables: effectiveHeaderVars.isNotEmpty ? effectiveHeaderVars : null,
              );
            } catch (err) {
              debugPrint('[MessageBloc] Error sending message to ${recipient.mobileNumber}: $err');
              return null;
            }
          }));

          for (final wamid in results) {
            if (wamid != null) {
              if (success == 0) dispatchedAt = DateTime.now();
              success++;
            } else {
              failure++;
            }
          }

          processedCount += chunk.length;
          emit(MessageSending(processedCount, total));
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
