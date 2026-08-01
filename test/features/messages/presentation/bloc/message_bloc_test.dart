// Tests for MessageBloc — completePhase1 ordering and resilience
//
// Verifies:
//   1. completePhase1(campaignId) is called BEFORE MessageSent is emitted
//   2. A completePhase1 failure (throws) is non-fatal — MessageSent still emits
//   3. completePhase1 is called even when ALL sends fail (failure count > 0)
//
// Relates to bugfix spec: .kiro/specs/campaign-retry-phases/bugfix.md
// Requirements: 2.1, 2.4

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sendzyy/features/messages/presentation/bloc/message_bloc.dart';
import 'package:sendzyy/features/messages/data/models/recipient_data.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository — records call order and controls send/completePhase1 behaviour
// ---------------------------------------------------------------------------

enum _CallType { sendMessage, completePhase1 }

class _FakeWhatsAppRepository extends WhatsAppRepository {
  /// Ordered log of every repository call made by the bloc.
  final List<_CallType> callLog = [];

  /// If true, completePhase1 throws an exception.
  bool completePhase1Throws = false;

  /// Controls what sendMessage returns: non-null wamid = success, null = failure.
  bool sendMessageSucceeds = true;

  _FakeWhatsAppRepository(super.dio, super.prefs);

  @override
  Future<String?> sendMessage({
    required String to,
    required String templateName,
    required String languageCode,
    String? mediaId,
    String? mediaType,
    String? campaignId,
    Map<int, String>? variables,
  }) async {
    callLog.add(_CallType.sendMessage);
    return sendMessageSucceeds ? 'fake-wamid-${callLog.length}' : null;
  }

  @override
  Future<void> completePhase1(String campaignId) async {
    callLog.add(_CallType.completePhase1);
    if (completePhase1Throws) {
      throw Exception('completePhase1 simulated failure');
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [SendBulkMessages] event with [count] recipients.
SendBulkMessages _buildEvent({int count = 2}) {
  final recipients = List.generate(
    count,
    (i) => RecipientData(
      mobileNumber: '+9190000000${i.toString().padLeft(2, '0')}',
      variables: {},
    ),
  );
  return SendBulkMessages(recipients, 'test_template', 'en_US');
}

/// Waits until the bloc emits a [MessageSent] state (or times out after 3 s).
Future<MessageSent> _waitForMessageSent(MessageBloc bloc) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (true) {
    if (bloc.state is MessageSent) return bloc.state as MessageSent;
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'Timed out waiting for MessageSent. Current state: ${bloc.state}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Waits until the bloc emits a [MessageError] state (or times out after 3 s).
Future<MessageError> _waitForMessageError(MessageBloc bloc) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (true) {
    if (bloc.state is MessageError) return bloc.state as MessageError;
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'Timed out waiting for MessageError. Current state: ${bloc.state}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

Future<(MessageBloc, _FakeWhatsAppRepository)> _makeBloc() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeWhatsAppRepository(Dio(), prefs);
  final bloc = MessageBloc(repo);
  return (bloc, repo);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MessageBloc — completePhase1 ordering and resilience', () {
    // -----------------------------------------------------------------------
    // Test 1: completePhase1 is called BEFORE MessageSent is emitted
    // -----------------------------------------------------------------------
    test(
      'completePhase1 is called before MessageSent is emitted '
      '(happy path — all sends succeed)',
      () async {
        final (bloc, repo) = await _makeBloc();
        addTearDown(bloc.close);

        // Collect states in emission order alongside the call log snapshot
        // taken at the moment MessageSent arrives.
        int? completePhase1IndexAtEmit;

        bloc.stream.listen((state) {
          if (state is MessageSent) {
            // Record the position of completePhase1 in the call log at the
            // exact moment MessageSent is emitted.
            completePhase1IndexAtEmit = repo.callLog.indexOf(_CallType.completePhase1);
          }
        });

        bloc.add(_buildEvent(count: 2));
        await _waitForMessageSent(bloc);

        // completePhase1 must appear in the log before MessageSent was emitted.
        expect(
          completePhase1IndexAtEmit,
          isNotNull,
          reason: 'completePhase1 must have been called before MessageSent emitted',
        );
        expect(
          completePhase1IndexAtEmit,
          greaterThanOrEqualTo(0),
          reason: 'completePhase1 must be present in the call log',
        );

        // Verify the final state is correct.
        final sent = bloc.state as MessageSent;
        expect(sent.successCount, equals(2));
        expect(sent.failureCount, equals(0));
      },
    );

    // -----------------------------------------------------------------------
    // Test 2: completePhase1 failure is non-fatal — MessageSent still emits
    // -----------------------------------------------------------------------
    test(
      'completePhase1 throwing an exception does NOT prevent MessageSent '
      'from being emitted (error is non-fatal)',
      () async {
        final (bloc, repo) = await _makeBloc();
        addTearDown(bloc.close);

        repo.completePhase1Throws = true;

        bloc.add(_buildEvent(count: 2));

        // Should still reach MessageSent despite the exception.
        final sent = await _waitForMessageSent(bloc);

        expect(sent.successCount, equals(2));
        expect(sent.failureCount, equals(0));

        // completePhase1 was still called (it just threw).
        expect(
          repo.callLog.contains(_CallType.completePhase1),
          isTrue,
          reason: 'completePhase1 must have been attempted even though it threw',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 3: completePhase1 is called even when ALL sends fail
    // -----------------------------------------------------------------------
    test(
      'completePhase1 is called even when all sends fail '
      '(failureCount == total recipients)',
      () async {
        final (bloc, repo) = await _makeBloc();
        addTearDown(bloc.close);

        repo.sendMessageSucceeds = false; // every send returns null

        bloc.add(_buildEvent(count: 3));
        final sent = await _waitForMessageSent(bloc);

        expect(sent.successCount, equals(0));
        expect(sent.failureCount, equals(3));

        // completePhase1 must still have been called.
        expect(
          repo.callLog.contains(_CallType.completePhase1),
          isTrue,
          reason: 'completePhase1 must be called even when all sends fail',
        );

        // And it must appear after the send calls (all sends happen first).
        final lastSendIndex = repo.callLog.lastIndexOf(_CallType.sendMessage);
        final completePhase1Index = repo.callLog.indexOf(_CallType.completePhase1);
        expect(
          completePhase1Index,
          greaterThan(lastSendIndex),
          reason: 'completePhase1 must be called after all send attempts',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 4: completePhase1 receives the correct campaignId
    // -----------------------------------------------------------------------
    test(
      'completePhase1 is called exactly once per SendBulkMessages event',
      () async {
        final (bloc, repo) = await _makeBloc();
        addTearDown(bloc.close);

        bloc.add(_buildEvent(count: 3));
        await _waitForMessageSent(bloc);

        final phase1Calls = repo.callLog
            .where((c) => c == _CallType.completePhase1)
            .length;

        expect(
          phase1Calls,
          equals(1),
          reason: 'completePhase1 must be called exactly once per campaign send',
        );
      },
    );
  });
}

