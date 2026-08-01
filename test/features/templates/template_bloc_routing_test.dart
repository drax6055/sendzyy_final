// Feature: template-category-utility-authentication, Property 16
// Property 16: BLoC routes auth fields to repository only for AUTHENTICATION category
// Validates: Requirements 10.2, 10.3

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendzyy/features/templates/data/models/app_entry.dart';
import 'package:sendzyy/features/templates/presentation/bloc/template_bloc.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake WhatsAppRepository — captures createTemplate() call arguments
// ---------------------------------------------------------------------------

/// Holds the captured arguments from the most recent createTemplate() call.
class _CapturedCreateTemplateArgs {
  final String name;
  final String category;
  final String language;
  final String body;
  final int? messageSendTtlSeconds;
  final String? codeDeliveryType;
  final List<dynamic>? appEntries;
  final bool? addSecurityRecommendation;
  final bool? addExpiryTime;
  final int? codeExpirationMinutes;
  final bool? zeroTapTosAccepted;

  _CapturedCreateTemplateArgs({
    required this.name,
    required this.category,
    required this.language,
    required this.body,
    this.messageSendTtlSeconds,
    this.codeDeliveryType,
    this.appEntries,
    this.addSecurityRecommendation,
    this.addExpiryTime,
    this.codeExpirationMinutes,
    this.zeroTapTosAccepted,
  });
}

/// A fake repository that records what was passed to createTemplate().
/// Returns true immediately without making any network calls.
class _FakeWhatsAppRepository extends WhatsAppRepository {
  _CapturedCreateTemplateArgs? lastCall;

  _FakeWhatsAppRepository(super.dio, super.prefs);

  @override
  Future<bool> createTemplate({
    required String name,
    required String category,
    String? subCategory,
    required String language,
    String? header,
    String? mediaSample,
    String? variableType,
    required String body,
    String? footer,
    List<Map<String, dynamic>>? buttons,
    PlatformFile? mediaFile,
    int? messageSendTtlSeconds,
    String? codeDeliveryType,
    List<dynamic>? appEntries,
    bool? addSecurityRecommendation,
    bool? addExpiryTime,
    int? codeExpirationMinutes,
    bool? zeroTapTosAccepted,
  }) async {
    lastCall = _CapturedCreateTemplateArgs(
      name: name,
      category: category,
      language: language,
      body: body,
      messageSendTtlSeconds: messageSendTtlSeconds,
      codeDeliveryType: codeDeliveryType,
      appEntries: appEntries,
      addSecurityRecommendation: addSecurityRecommendation,
      addExpiryTime: addExpiryTime,
      codeExpirationMinutes: codeExpirationMinutes,
      zeroTapTosAccepted: zeroTapTosAccepted,
    );
    return true;
  }

  @override
  Future<List<dynamic>> fetchTemplates() async => [];
}

// ---------------------------------------------------------------------------
// Helpers — property-based test runner
// ---------------------------------------------------------------------------

void forAll(int iterations, Random rng, void Function(Random r) body) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

// ---------------------------------------------------------------------------
// Generators for random auth field values
// ---------------------------------------------------------------------------

const List<String> _deliveryTypes = ['ZERO_TAP', 'ONE_TAP', 'COPY_CODE'];
const List<String> _nonAuthCategories = ['MARKETING', 'UTILITY'];

/// Generates a random non-empty list of AppEntry (1–3 entries).
List<AppEntry> _randomAppEntries(Random r) {
  final count = 1 + r.nextInt(3);
  return List.generate(
    count,
    (_) => AppEntry(
      packageName: 'com.example.app${r.nextInt(1000)}',
      signatureHash: 'ABCDE${r.nextInt(100000).toString().padLeft(6, '0')}'.substring(0, 11),
    ),
  );
}

/// Builds a CreateTemplate event with random auth fields and the given category.
CreateTemplate _buildEvent({
  required Random r,
  required String category,
}) {
  return CreateTemplate(
    name: 'test_template_${r.nextInt(10000)}',
    category: category,
    language: 'en_US',
    body: 'Test body',
    messageSendTtlSeconds: r.nextBool() ? (30 + r.nextInt(86370)) : null,
    codeDeliveryType: _pick(r, _deliveryTypes),
    appEntries: _randomAppEntries(r),
    addSecurityRecommendation: r.nextBool(),
    addExpiryTime: r.nextBool(),
    codeExpirationMinutes: r.nextBool() ? (1 + r.nextInt(60)) : null,
    zeroTapTosAccepted: r.nextBool(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Fixed seed for reproducibility; change to Random() for true randomness.
  final rng = Random(7);
  const iterations = 100;

  late _FakeWhatsAppRepository fakeRepo;
  late TemplateBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeRepo = _FakeWhatsAppRepository(Dio(), prefs);
    bloc = TemplateBloc(fakeRepo);
  });

  tearDown(() {
    bloc.close();
  });

  // -------------------------------------------------------------------------
  // Property 16a — AUTHENTICATION: all auth fields forwarded to repository
  // -------------------------------------------------------------------------
  group('Property 16a — AUTHENTICATION category forwards auth fields', () {
    test(
      'P16a: for any CreateTemplate with category==AUTHENTICATION, '
      'all auth-specific fields are passed to the repository',
      () async {
        await forAllAsync(iterations, rng, (r) async {
          final event = _buildEvent(r: r, category: 'AUTHENTICATION');

          bloc.add(event);

          // Wait for the BLoC to process the event and call the repository.
          await _waitForRepoCall(fakeRepo);

          final captured = fakeRepo.lastCall!;

          // Auth-specific fields must be forwarded as-is.
          expect(
            captured.codeDeliveryType,
            equals(event.codeDeliveryType),
            reason: 'codeDeliveryType must be forwarded for AUTHENTICATION',
          );
          expect(
            captured.appEntries,
            equals(event.appEntries),
            reason: 'appEntries must be forwarded for AUTHENTICATION',
          );
          expect(
            captured.addSecurityRecommendation,
            equals(event.addSecurityRecommendation),
            reason: 'addSecurityRecommendation must be forwarded for AUTHENTICATION',
          );
          expect(
            captured.addExpiryTime,
            equals(event.addExpiryTime),
            reason: 'addExpiryTime must be forwarded for AUTHENTICATION',
          );
          expect(
            captured.codeExpirationMinutes,
            equals(event.codeExpirationMinutes),
            reason: 'codeExpirationMinutes must be forwarded for AUTHENTICATION',
          );
          expect(
            captured.zeroTapTosAccepted,
            equals(event.zeroTapTosAccepted),
            reason: 'zeroTapTosAccepted must be forwarded for AUTHENTICATION',
          );
        });
      },
    );

    test(
      'P16a: messageSendTtlSeconds is forwarded for AUTHENTICATION',
      () async {
        await forAllAsync(iterations, rng, (r) async {
          final event = _buildEvent(r: r, category: 'AUTHENTICATION');

          bloc.add(event);
          await _waitForRepoCall(fakeRepo);

          expect(
            fakeRepo.lastCall!.messageSendTtlSeconds,
            equals(event.messageSendTtlSeconds),
            reason: 'messageSendTtlSeconds must be forwarded for AUTHENTICATION',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 16b — MARKETING/UTILITY: auth fields are NOT passed to repository
  // -------------------------------------------------------------------------
  group('Property 16b — non-AUTHENTICATION category ignores auth fields', () {
    test(
      'P16b: for any CreateTemplate with category==MARKETING or UTILITY, '
      'auth-specific fields are null when passed to the repository',
      () async {
        await forAllAsync(iterations, rng, (r) async {
          final category = _pick(r, _nonAuthCategories);
          final event = _buildEvent(r: r, category: category);

          bloc.add(event);
          await _waitForRepoCall(fakeRepo);

          final captured = fakeRepo.lastCall!;

          expect(
            captured.codeDeliveryType,
            isNull,
            reason: 'codeDeliveryType must be null for $category',
          );
          expect(
            captured.appEntries,
            isNull,
            reason: 'appEntries must be null for $category',
          );
          expect(
            captured.addSecurityRecommendation,
            isNull,
            reason: 'addSecurityRecommendation must be null for $category',
          );
          expect(
            captured.addExpiryTime,
            isNull,
            reason: 'addExpiryTime must be null for $category',
          );
          expect(
            captured.codeExpirationMinutes,
            isNull,
            reason: 'codeExpirationMinutes must be null for $category',
          );
          expect(
            captured.zeroTapTosAccepted,
            isNull,
            reason: 'zeroTapTosAccepted must be null for $category',
          );
        });
      },
    );

    test(
      'P16b: messageSendTtlSeconds is forwarded for UTILITY but not for MARKETING',
      () async {
        await forAllAsync(iterations, rng, (r) async {
          // UTILITY: TTL should be forwarded when non-null
          final utilityEvent = _buildEvent(r: r, category: 'UTILITY');
          bloc.add(utilityEvent);
          await _waitForRepoCall(fakeRepo);
          expect(
            fakeRepo.lastCall!.messageSendTtlSeconds,
            equals(utilityEvent.messageSendTtlSeconds),
            reason: 'messageSendTtlSeconds must be forwarded for UTILITY',
          );

          // MARKETING: TTL should be null (ignored)
          final marketingEvent = CreateTemplate(
            name: 'mkt_${r.nextInt(10000)}',
            category: 'MARKETING',
            language: 'en_US',
            body: 'Marketing body',
            messageSendTtlSeconds: 600, // explicitly set, should be ignored
            codeDeliveryType: 'ZERO_TAP',
            appEntries: _randomAppEntries(r),
            addSecurityRecommendation: true,
            addExpiryTime: false,
            codeExpirationMinutes: 10,
            zeroTapTosAccepted: true,
          );
          bloc.add(marketingEvent);
          await _waitForRepoCall(fakeRepo);
          expect(
            fakeRepo.lastCall!.messageSendTtlSeconds,
            isNull,
            reason: 'messageSendTtlSeconds must be null for MARKETING',
          );
        });
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Async forAll helper
// ---------------------------------------------------------------------------

Future<void> forAllAsync(
  int iterations,
  Random rng,
  Future<void> Function(Random r) body,
) async {
  for (var i = 0; i < iterations; i++) {
    await body(rng);
  }
}

/// Polls until the fake repository has recorded a new call, then clears it.
/// Times out after 2 seconds.
Future<void> _waitForRepoCall(_FakeWhatsAppRepository repo) async {
  repo.lastCall = null;
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (repo.lastCall == null) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for repository.createTemplate() to be called');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

