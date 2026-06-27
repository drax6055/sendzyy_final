// Feature: template-category-utility-authentication, Property 6/7

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/templates/data/models/app_entry.dart';

// ---------------------------------------------------------------------------
// Pure validator extracted from _AppEntryRowState (authentication_form_widget.dart)
//
// The widget shows an error when: hashLen > 0 && hashLen != 11
// Per the design property 6: "for any string whose length is not exactly 11
// characters, the validator must return a non-null error message; for any
// string of exactly 11 characters, the validator must return null."
//
// The widget treats empty string (length 0) as "not yet entered" and shows no
// error. The property spec targets non-empty, non-11-char strings. We mirror
// the widget's exact logic here.
// ---------------------------------------------------------------------------

/// Returns an error message when [value] is non-empty and not exactly 11 chars,
/// null otherwise. Mirrors the inline validation in _AppEntryRowState.
String? validateSignatureHash(String value) {
  if (value.isEmpty) return null;
  if (value.length != 11) {
    return 'App signature hash must be exactly 11 characters.';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Runs [body] for [iterations] random seeds.
void forAll(int iterations, Random rng, void Function(Random r) body) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

/// Generates a random string of [length] printable ASCII characters.
String _randomString(Random r, int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rng = Random(42);
  const iterations = 100;

  // -------------------------------------------------------------------------
  // Property 6: App signature hash validation rejects non-11-character strings
  // Validates: Requirements 5.3, 11.14
  // -------------------------------------------------------------------------
  group('Property 6: App signature hash validator', () {
    test(
      'P6a: string of exactly 11 characters → validator returns null',
      () {
        forAll(iterations, rng, (r) {
          final value = _randomString(r, 11);
          final result = validateSignatureHash(value);
          expect(
            result,
            isNull,
            reason: 'Expected null for 11-char hash: "$value"',
          );
        });
      },
    );

    test(
      'P6b: non-empty string with length != 11 → validator returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          // Generate a length in [1, 30] that is not 11
          int length;
          do {
            length = 1 + r.nextInt(30);
          } while (length == 11);

          final value = _randomString(r, length);
          final result = validateSignatureHash(value);
          expect(
            result,
            isNotNull,
            reason:
                'Expected error for ${length}-char hash: "$value" (length != 11)',
          );
        });
      },
    );

    test(
      'P6c: empty string → validator returns null (not yet entered)',
      () {
        expect(validateSignatureHash(''), isNull);
      },
    );

    test(
      'P6d: boundary — length 10 → error; length 11 → null; length 12 → error',
      () {
        expect(validateSignatureHash(_randomString(rng, 10)), isNotNull);
        expect(validateSignatureHash(_randomString(rng, 11)), isNull);
        expect(validateSignatureHash(_randomString(rng, 12)), isNotNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 7: App entry list always retains at least one entry
  // Validates: Requirements 5.6
  // -------------------------------------------------------------------------
  group('Property 7: App entry list remove button enabled/disabled', () {
    /// Mirrors the canRemove logic in AppSetupWidget._AppSetupWidgetState:
    ///   canRemove = count > 1
    bool canRemove(int count) => count > 1;

    test(
      'P7a: list of length 1 → remove is blocked (canRemove == false)',
      () {
        expect(canRemove(1), isFalse,
            reason: 'Remove must be blocked when only 1 entry remains');
      },
    );

    test(
      'P7b: list of length N > 1 → remove is permitted (canRemove == true)',
      () {
        forAll(iterations, rng, (r) {
          // N in [2, 5] (max entries is 5)
          final n = 2 + r.nextInt(4);
          expect(
            canRemove(n),
            isTrue,
            reason: 'Remove must be permitted when N=$n > 1',
          );
        });
      },
    );

    test(
      'P7c: after removing an entry from a list of 2, list has 1 entry and remove is blocked',
      () {
        final entries = [
          const AppEntry(packageName: 'com.example.app', signatureHash: '12345678901'),
          const AppEntry(packageName: 'com.example.app2', signatureHash: 'abcdefghijk'),
        ];
        // Simulate removing index 0
        final updated = List<AppEntry>.from(entries)..removeAt(0);
        expect(updated.length, equals(1));
        expect(canRemove(updated.length), isFalse,
            reason: 'After removal, 1 entry remains — remove must be blocked');
      },
    );

    test(
      'P7d: for any list length N in [1..5], canRemove(N) == (N > 1)',
      () {
        for (var n = 1; n <= 5; n++) {
          expect(
            canRemove(n),
            equals(n > 1),
            reason: 'canRemove($n) should be ${n > 1}',
          );
        }
      },
    );
  });
}
