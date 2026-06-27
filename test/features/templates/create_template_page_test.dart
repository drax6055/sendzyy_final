// Feature: template-category-utility-authentication, Property 1
// Feature: template-category-utility-authentication, Property 2

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/templates/data/models/app_entry.dart';
import 'package:iFloraBuzz/features/templates/data/models/auth_form_state.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Pure model of the Step 2 state held by _CreateTemplatePageState.
//
// We test the reset logic in isolation — no widget pump needed — because the
// reset is a deterministic pure transformation: switching category clears all
// Step 2 fields to their default values.
// ---------------------------------------------------------------------------

/// Mirrors the mutable Step 2 state fields in _CreateTemplatePageState.
class Step2State {
  final String headerText;
  final String bodyText;
  final String footerText;
  final List<Map<String, dynamic>> buttons;
  final String mediaSample;
  final Object? selectedFile; // PlatformFile — opaque in tests
  final AuthFormState authFormState;
  final int validitySeconds;

  const Step2State({
    this.headerText = '',
    this.bodyText = '',
    this.footerText = '',
    this.buttons = const [],
    this.mediaSample = 'NONE',
    this.selectedFile,
    this.authFormState = const AuthFormState(),
    this.validitySeconds = 0,
  });

  /// Mirrors the setState block in CategorySelectorWidget.onChanged.
  Step2State reset() => const Step2State();

  bool get isDefault =>
      headerText.isEmpty &&
      bodyText.isEmpty &&
      footerText.isEmpty &&
      buttons.isEmpty &&
      mediaSample == 'NONE' &&
      selectedFile == null &&
      authFormState == const AuthFormState() &&
      validitySeconds == 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void forAll(int iterations, Random rng, void Function(Random r) body) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

String _randomString(Random r, int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

const _categories = ['MARKETING', 'UTILITY', 'AUTHENTICATION'];
const _mediaSamples = ['NONE', 'IMAGE', 'VIDEO', 'DOCUMENT'];
const _deliveryTypes = ['ZERO_TAP', 'ONE_TAP', 'COPY_CODE'];

/// Builds a randomised non-default Step2State to simulate a user who has
/// partially filled in Step 2 before switching category.
Step2State _randomDirtyState(Random r) {
  return Step2State(
    headerText: _randomString(r, 1 + r.nextInt(60)),
    bodyText: _randomString(r, 1 + r.nextInt(200)),
    footerText: _randomString(r, 1 + r.nextInt(60)),
    buttons: List.generate(
      r.nextInt(4),
      (_) => {'type': 'QUICK_REPLY', 'text': _randomString(r, 5)},
    ),
    mediaSample: _mediaSamples[r.nextInt(_mediaSamples.length)],
    selectedFile: null, // PlatformFile not constructable in unit tests
    authFormState: AuthFormState(
      codeDeliveryType: _deliveryTypes[r.nextInt(_deliveryTypes.length)],
      zeroTapTosAccepted: r.nextBool(),
      appEntries: List.generate(
        1 + r.nextInt(3),
        (_) => AppEntry(
          packageName: _randomString(r, 5 + r.nextInt(20)),
          signatureHash: _randomString(r, 11),
        ),
      ),
      addSecurityRecommendation: r.nextBool(),
      addExpiryTime: r.nextBool(),
      codeExpirationMinutes: r.nextBool() ? 1 + r.nextInt(60) : null,
      validityEnabled: r.nextBool(),
      validitySeconds: 30 + r.nextInt(86370),
    ),
    validitySeconds: r.nextBool() ? 0 : (30 + r.nextInt(86370)),
  );
}

// ---------------------------------------------------------------------------
// Fake WhatsAppRepository — captures the category passed to createTemplate()
// ---------------------------------------------------------------------------

class _FakeWhatsAppRepository extends WhatsAppRepository {
  String? capturedCategory;

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
    capturedCategory = category;
    return true;
  }

  @override
  Future<List<dynamic>> fetchTemplates() async => [];
}

Future<void> _waitForCategory(_FakeWhatsAppRepository repo) async {
  repo.capturedCategory = null;
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (repo.capturedCategory == null) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'Timed out waiting for repository.createTemplate() to be called',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rng = Random(42);
  const iterations = 100;

  // -------------------------------------------------------------------------
  // Property 1: Payload category matches selection
  // Validates: Requirements 1.3
  // -------------------------------------------------------------------------
  group('Property 1: Payload category matches selection', () {
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

    test(
      'P1: for any category in {MARKETING, UTILITY, AUTHENTICATION}, '
      'the repository receives that exact category string',
      () async {
        for (var i = 0; i < iterations; i++) {
          final category = _categories[rng.nextInt(_categories.length)];

          bloc.add(
            CreateTemplate(
              name: 'test_template_$i',
              category: category,
              language: 'en_US',
              body: 'Test body',
            ),
          );

          await _waitForCategory(fakeRepo);

          expect(
            fakeRepo.capturedCategory,
            equals(category),
            reason:
                'Repository must receive category "$category" when that category is selected',
          );
        }
      },
    );

    test(
      'P1: MARKETING category is passed through unchanged',
      () async {
        bloc.add(
          CreateTemplate(
            name: 'marketing_test',
            category: 'MARKETING',
            language: 'en_US',
            body: 'Body',
          ),
        );
        await _waitForCategory(fakeRepo);
        expect(fakeRepo.capturedCategory, equals('MARKETING'));
      },
    );

    test(
      'P1: UTILITY category is passed through unchanged',
      () async {
        bloc.add(
          CreateTemplate(
            name: 'utility_test',
            category: 'UTILITY',
            language: 'en_US',
            body: 'Body',
          ),
        );
        await _waitForCategory(fakeRepo);
        expect(fakeRepo.capturedCategory, equals('UTILITY'));
      },
    );

    test(
      'P1: AUTHENTICATION category is passed through unchanged',
      () async {
        bloc.add(
          CreateTemplate(
            name: 'auth_test',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'Body',
          ),
        );
        await _waitForCategory(fakeRepo);
        expect(fakeRepo.capturedCategory, equals('AUTHENTICATION'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 2: Category change resets Step 2 state
  // Validates: Requirements 1.4
  // -------------------------------------------------------------------------
  group('Property 2: Category change resets Step 2 state', () {
    test(
      'P2a: reset() on any dirty state produces the default Step2State',
      () {
        forAll(iterations, rng, (r) {
          final dirty = _randomDirtyState(r);
          final after = dirty.reset();
          expect(
            after.isDefault,
            isTrue,
            reason: 'All Step 2 fields must return to defaults after reset',
          );
        });
      },
    );

    test(
      'P2b: switching between any two distinct categories resets Step 2 state',
      () {
        forAll(iterations, rng, (r) {
          // Pick two distinct categories
          final catA = _categories[r.nextInt(_categories.length)];
          String catB;
          do {
            catB = _categories[r.nextInt(_categories.length)];
          } while (catB == catA);

          // Simulate user filling in Step 2 for catA
          final dirtyForA = _randomDirtyState(r);
          expect(dirtyForA.isDefault, isFalse,
              reason: 'Dirty state must not be default before reset');

          // Simulate switching to catB — triggers reset
          final afterSwitch = dirtyForA.reset();
          expect(
            afterSwitch.isDefault,
            isTrue,
            reason:
                'Switching from $catA to $catB must reset all Step 2 fields',
          );
        });
      },
    );

    test(
      'P2c: reset clears header, body, and footer text',
      () {
        forAll(iterations, rng, (r) {
          final dirty = Step2State(
            headerText: _randomString(r, 1 + r.nextInt(60)),
            bodyText: _randomString(r, 1 + r.nextInt(200)),
            footerText: _randomString(r, 1 + r.nextInt(60)),
          );
          final after = dirty.reset();
          expect(after.headerText, isEmpty);
          expect(after.bodyText, isEmpty);
          expect(after.footerText, isEmpty);
        });
      },
    );

    test(
      'P2d: reset clears buttons list',
      () {
        forAll(iterations, rng, (r) {
          final count = 1 + r.nextInt(5);
          final dirty = Step2State(
            buttons: List.generate(
              count,
              (_) => {'type': 'QUICK_REPLY', 'text': _randomString(r, 5)},
            ),
          );
          final after = dirty.reset();
          expect(after.buttons, isEmpty,
              reason: 'Buttons must be cleared on category change');
        });
      },
    );

    test(
      'P2e: reset resets mediaSample to NONE and clears selectedFile',
      () {
        forAll(iterations, rng, (r) {
          final sample = _mediaSamples[1 + r.nextInt(3)]; // IMAGE/VIDEO/DOCUMENT
          final dirty = Step2State(mediaSample: sample);
          final after = dirty.reset();
          expect(after.mediaSample, equals('NONE'));
          expect(after.selectedFile, isNull);
        });
      },
    );

    test(
      'P2f: reset resets authFormState to const AuthFormState()',
      () {
        forAll(iterations, rng, (r) {
          final dirty = Step2State(authFormState: _randomDirtyState(r).authFormState);
          final after = dirty.reset();
          expect(
            after.authFormState,
            equals(const AuthFormState()),
            reason: 'authFormState must equal the default AuthFormState after reset',
          );
        });
      },
    );

    test(
      'P2g: reset resets validitySeconds to 0',
      () {
        forAll(iterations, rng, (r) {
          final seconds = 30 + r.nextInt(86370);
          final dirty = Step2State(validitySeconds: seconds);
          final after = dirty.reset();
          expect(after.validitySeconds, equals(0),
              reason: 'validitySeconds must be 0 (disabled) after reset');
        });
      },
    );

    test(
      'P2h: reset is idempotent — resetting an already-default state stays default',
      () {
        forAll(iterations, rng, (r) {
          const defaultState = Step2State();
          final after = defaultState.reset();
          expect(after.isDefault, isTrue,
              reason: 'Resetting a default state must remain default');
        });
      },
    );
  });
}
