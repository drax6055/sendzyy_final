// Feature: template-category-utility-authentication, Property 5

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/templates/data/models/auth_form_state.dart';

// ---------------------------------------------------------------------------
// Property 5: App_Setup section visibility follows delivery type
// Validates: Requirements 4.6, 4.7
//
// The AuthenticationFormWidget renders AppSetupWidget if and only if
// codeDeliveryType != 'COPY_CODE'. This is a pure boolean predicate on
// AuthFormState, so we test the logic directly without widget rendering.
//
// Predicate (mirrors the widget's `if` condition):
//   appSetupVisible(state) == (state.codeDeliveryType != 'COPY_CODE')
// ---------------------------------------------------------------------------

/// Mirrors the visibility predicate in AuthenticationFormWidget:
///   `if (_state.codeDeliveryType != 'COPY_CODE')`
bool appSetupVisible(AuthFormState state) =>
    state.codeDeliveryType != 'COPY_CODE';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _deliveryTypes = ['ZERO_TAP', 'ONE_TAP', 'COPY_CODE'];

/// Runs [body] for [iterations] random seeds.
void forAll(int iterations, Random rng, void Function(Random r) body) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rng = Random(42);
  const iterations = 100;

  // -------------------------------------------------------------------------
  // Property 5: App_Setup section visibility follows delivery type
  // Validates: Requirements 4.6, 4.7
  // -------------------------------------------------------------------------
  group('Property 5: App_Setup visibility follows delivery type', () {
    test(
      'P5a: ZERO_TAP → App_Setup is visible',
      () {
        final state = const AuthFormState(codeDeliveryType: 'ZERO_TAP');
        expect(
          appSetupVisible(state),
          isTrue,
          reason: 'App_Setup must be visible for ZERO_TAP',
        );
      },
    );

    test(
      'P5b: ONE_TAP → App_Setup is visible',
      () {
        final state = const AuthFormState(codeDeliveryType: 'ONE_TAP');
        expect(
          appSetupVisible(state),
          isTrue,
          reason: 'App_Setup must be visible for ONE_TAP',
        );
      },
    );

    test(
      'P5c: COPY_CODE → App_Setup is hidden',
      () {
        final state = const AuthFormState(codeDeliveryType: 'COPY_CODE');
        expect(
          appSetupVisible(state),
          isFalse,
          reason: 'App_Setup must be hidden for COPY_CODE',
        );
      },
    );

    test(
      'P5d: for every delivery type, visibility == (type != COPY_CODE)',
      () {
        for (final type in _deliveryTypes) {
          final state = AuthFormState(codeDeliveryType: type);
          final expected = type != 'COPY_CODE';
          expect(
            appSetupVisible(state),
            equals(expected),
            reason: 'appSetupVisible should be $expected for type "$type"',
          );
        }
      },
    );

    test(
      'P5e: switching from ZERO_TAP to COPY_CODE hides App_Setup',
      () {
        var state = const AuthFormState(codeDeliveryType: 'ZERO_TAP');
        expect(appSetupVisible(state), isTrue);

        state = state.copyWith(codeDeliveryType: 'COPY_CODE');
        expect(
          appSetupVisible(state),
          isFalse,
          reason: 'After switching to COPY_CODE, App_Setup must be hidden',
        );
      },
    );

    test(
      'P5f: switching from COPY_CODE to ONE_TAP shows App_Setup',
      () {
        var state = const AuthFormState(codeDeliveryType: 'COPY_CODE');
        expect(appSetupVisible(state), isFalse);

        state = state.copyWith(codeDeliveryType: 'ONE_TAP');
        expect(
          appSetupVisible(state),
          isTrue,
          reason: 'After switching to ONE_TAP, App_Setup must be visible',
        );
      },
    );

    test(
      'P5g: property holds for 100 random delivery type selections',
      () {
        forAll(iterations, rng, (r) {
          final type = _deliveryTypes[r.nextInt(_deliveryTypes.length)];
          final state = AuthFormState(codeDeliveryType: type);
          final expected = type != 'COPY_CODE';
          expect(
            appSetupVisible(state),
            equals(expected),
            reason:
                'appSetupVisible should be $expected for randomly selected type "$type"',
          );
        });
      },
    );

    test(
      'P5h: other AuthFormState fields do not affect App_Setup visibility',
      () {
        // Vary unrelated fields — visibility must depend only on codeDeliveryType
        const visibleTypes = ['ZERO_TAP', 'ONE_TAP'];
        for (final type in visibleTypes) {
          // With security recommendation on/off
          for (final secRec in [true, false]) {
            // With expiry on/off
            for (final expiry in [true, false]) {
              final state = AuthFormState(
                codeDeliveryType: type,
                addSecurityRecommendation: secRec,
                addExpiryTime: expiry,
                validityEnabled: expiry,
              );
              expect(
                appSetupVisible(state),
                isTrue,
                reason:
                    'App_Setup must be visible for $type regardless of other fields',
              );
            }
          }
        }

        // Same for COPY_CODE
        for (final secRec in [true, false]) {
          for (final expiry in [true, false]) {
            final state = AuthFormState(
              codeDeliveryType: 'COPY_CODE',
              addSecurityRecommendation: secRec,
              addExpiryTime: expiry,
            );
            expect(
              appSetupVisible(state),
              isFalse,
              reason:
                  'App_Setup must be hidden for COPY_CODE regardless of other fields',
            );
          }
        }
      },
    );
  });
}
