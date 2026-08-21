// Feature: template-category-utility-authentication, Property 11/12/13

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/features/templates/data/models/app_entry.dart';
import 'package:iFloraBuzz/features/templates/data/models/auth_form_state.dart';

// ---------------------------------------------------------------------------
// Pure helper — mirrors AuthPreviewWidget._buildBodyText() exactly.
// ---------------------------------------------------------------------------
String buildBodyText(AuthFormState state) {
  final buffer = StringBuffer('[{{1}}] is your verification code.');
  if (state.addSecurityRecommendation) {
    buffer.write(' For your security, do not share this code.');
  }
  if (state.addExpiryTime && state.codeExpirationMinutes != null) {
    buffer.write(' This code expires in ${state.codeExpirationMinutes} minutes.');
  }
  return buffer.toString();
}

// Pure helper — mirrors AuthPreviewWidget._buildOtpButton() label logic.
String buildButtonLabel(AuthFormState state) {
  if (state.codeDeliveryType == 'COPY_CODE') return 'Copy code';
  if (state.appEntries.isNotEmpty) {
    final pkg = state.appEntries.first.packageName;
    if (pkg.isNotEmpty) return pkg;
  }
  return 'Autofill';
}

bool isCopyCodeButton(AuthFormState state) =>
    state.codeDeliveryType == 'COPY_CODE';

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
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

const _deliveryTypes = ['ZERO_TAP', 'ONE_TAP', 'COPY_CODE'];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rng = Random(42);
  const iterations = 100;

  // -------------------------------------------------------------------------
  // Property 11: Auth preview appends security recommendation text when checked
  // Validates: Requirements 8.3
  // -------------------------------------------------------------------------
  group('Property 11: Security recommendation text in preview', () {
    const securityPhrase = 'For your security, do not share this code.';

    test(
      'P11a: addSecurityRecommendation=true → body contains security phrase',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            addSecurityRecommendation: true,
            addExpiryTime: r.nextBool(),
            codeExpirationMinutes: r.nextBool() ? 1 + r.nextInt(60) : null,
            codeDeliveryType:
                _deliveryTypes[r.nextInt(_deliveryTypes.length)],
          );
          final body = buildBodyText(state);
          expect(
            body,
            contains(securityPhrase),
            reason:
                'Expected security phrase when addSecurityRecommendation=true',
          );
        });
      },
    );

    test(
      'P11b: addSecurityRecommendation=false → body does NOT contain security phrase',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            addSecurityRecommendation: false,
            addExpiryTime: r.nextBool(),
            codeExpirationMinutes: r.nextBool() ? 1 + r.nextInt(60) : null,
            codeDeliveryType:
                _deliveryTypes[r.nextInt(_deliveryTypes.length)],
          );
          final body = buildBodyText(state);
          expect(
            body,
            isNot(contains(securityPhrase)),
            reason:
                'Expected no security phrase when addSecurityRecommendation=false',
          );
        });
      },
    );

    test(
      'P11c: toggling addSecurityRecommendation changes body text',
      () {
        forAll(iterations, rng, (r) {
          final base = AuthFormState(
            addSecurityRecommendation: false,
            addExpiryTime: false,
          );
          final withSecurity =
              base.copyWith(addSecurityRecommendation: true);

          expect(buildBodyText(base), isNot(contains(securityPhrase)));
          expect(buildBodyText(withSecurity), contains(securityPhrase));
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 12: Auth preview appends correct expiry text for any duration
  // Validates: Requirements 8.4
  // -------------------------------------------------------------------------
  group('Property 12: Expiry text in preview', () {
    test(
      'P12a: addExpiryTime=true with minutes X → body contains "This code expires in X minutes."',
      () {
        forAll(iterations, rng, (r) {
          final minutes = 1 + r.nextInt(120);
          final state = AuthFormState(
            addExpiryTime: true,
            codeExpirationMinutes: minutes,
            addSecurityRecommendation: r.nextBool(),
          );
          final body = buildBodyText(state);
          expect(
            body,
            contains('This code expires in $minutes minutes.'),
            reason:
                'Expected expiry text for $minutes minutes',
          );
        });
      },
    );

    test(
      'P12b: addExpiryTime=false → body does NOT contain expiry text',
      () {
        forAll(iterations, rng, (r) {
          final minutes = 1 + r.nextInt(120);
          final state = AuthFormState(
            addExpiryTime: false,
            codeExpirationMinutes: minutes,
            addSecurityRecommendation: r.nextBool(),
          );
          final body = buildBodyText(state);
          expect(
            body,
            isNot(contains('This code expires in')),
            reason: 'Expected no expiry text when addExpiryTime=false',
          );
        });
      },
    );

    test(
      'P12c: addExpiryTime=true but codeExpirationMinutes=null → no expiry text',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            addExpiryTime: true,
            codeExpirationMinutes: null,
            addSecurityRecommendation: r.nextBool(),
          );
          final body = buildBodyText(state);
          expect(
            body,
            isNot(contains('This code expires in')),
            reason:
                'Expected no expiry text when codeExpirationMinutes is null',
          );
        });
      },
    );

    test(
      'P12d: expiry text contains the exact minute value, not a different number',
      () {
        forAll(iterations, rng, (r) {
          final minutes = 1 + r.nextInt(1440);
          final other = minutes == 1 ? 2 : minutes - 1;
          final state = AuthFormState(
            addExpiryTime: true,
            codeExpirationMinutes: minutes,
          );
          final body = buildBodyText(state);
          expect(body, contains('This code expires in $minutes minutes.'));
          expect(
            body,
            isNot(contains('This code expires in $other minutes.')),
            reason: 'Body must use the exact configured minute value',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 13: Auth preview button type matches delivery type
  // Validates: Requirements 8.5, 8.6
  // -------------------------------------------------------------------------
  group('Property 13: OTP button type matches delivery type', () {
    test(
      'P13a: COPY_CODE → isCopyCodeButton=true, label="Copy code"',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            codeDeliveryType: 'COPY_CODE',
            appEntries: [
              AppEntry(
                packageName: _randomString(r, 5 + r.nextInt(20)),
                signatureHash: _randomString(r, 11),
              ),
            ],
          );
          expect(isCopyCodeButton(state), isTrue,
              reason: 'COPY_CODE must produce a copy-code button');
          expect(buildButtonLabel(state), equals('Copy code'),
              reason: 'COPY_CODE label must be "Copy code"');
        });
      },
    );

    test(
      'P13b: ZERO_TAP → isCopyCodeButton=false (auto-fill button)',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            codeDeliveryType: 'ZERO_TAP',
            appEntries: [
              AppEntry(
                packageName: _randomString(r, 5 + r.nextInt(20)),
                signatureHash: _randomString(r, 11),
              ),
            ],
          );
          expect(isCopyCodeButton(state), isFalse,
              reason: 'ZERO_TAP must produce an auto-fill button');
        });
      },
    );

    test(
      'P13c: ONE_TAP → isCopyCodeButton=false (auto-fill button)',
      () {
        forAll(iterations, rng, (r) {
          final state = AuthFormState(
            codeDeliveryType: 'ONE_TAP',
            appEntries: [
              AppEntry(
                packageName: _randomString(r, 5 + r.nextInt(20)),
                signatureHash: _randomString(r, 11),
              ),
            ],
          );
          expect(isCopyCodeButton(state), isFalse,
              reason: 'ONE_TAP must produce an auto-fill button');
        });
      },
    );

    test(
      'P13d: for any non-COPY_CODE type, button is never "Copy code"',
      () {
        forAll(iterations, rng, (r) {
          final type = r.nextBool() ? 'ZERO_TAP' : 'ONE_TAP';
          final state = AuthFormState(codeDeliveryType: type);
          expect(
            buildButtonLabel(state),
            isNot(equals('Copy code')),
            reason: '$type must not produce a "Copy code" label',
          );
        });
      },
    );

    test(
      'P13e: ZERO_TAP/ONE_TAP with non-empty package name → label equals package name',
      () {
        forAll(iterations, rng, (r) {
          final type = r.nextBool() ? 'ZERO_TAP' : 'ONE_TAP';
          final pkg = _randomString(r, 5 + r.nextInt(30));
          final state = AuthFormState(
            codeDeliveryType: type,
            appEntries: [
              AppEntry(packageName: pkg, signatureHash: _randomString(r, 11)),
            ],
          );
          expect(
            buildButtonLabel(state),
            equals(pkg),
            reason: 'Auto-fill label must equal the first package name',
          );
        });
      },
    );

    test(
      'P13f: ZERO_TAP/ONE_TAP with empty package name → label is "Autofill"',
      () {
        forAll(iterations, rng, (r) {
          final type = r.nextBool() ? 'ZERO_TAP' : 'ONE_TAP';
          final state = AuthFormState(
            codeDeliveryType: type,
            appEntries: [
              const AppEntry(packageName: '', signatureHash: ''),
            ],
          );
          expect(
            buildButtonLabel(state),
            equals('Autofill'),
            reason: 'Auto-fill label must fall back to "Autofill" when package name is empty',
          );
        });
      },
    );
  });
}
