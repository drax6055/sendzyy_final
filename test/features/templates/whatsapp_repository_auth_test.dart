// Feature: template-category-utility-authentication, Property 3/4/8/9/10/14/15
//
// Property 3:  Validity period toggle OFF omits TTL from payload
//              Validates: Requirements 3.4, 7.3
// Property 4:  Validity period value in payload matches selected duration
//              Validates: Requirements 3.7, 7.4
// Property 8:  All configured app entries appear in submission payload
//              Validates: Requirements 5.7, 9.4
// Property 9:  Security recommendation flag matches checkbox state
//              Validates: Requirements 6.4, 9.2
// Property 10: Code expiration minutes matches input
//              Validates: Requirements 6.6, 9.5
// Property 14: Auth payload contains only BODY and BUTTONS
//              Validates: Requirements 9.1, 9.7
// Property 15: OTP button otp_type matches delivery type
//              Validates: Requirements 9.3

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sendzyy/features/templates/data/models/app_entry.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';

// ---------------------------------------------------------------------------
// Intercepting Dio adapter — captures the last POST body as a decoded Map
// ---------------------------------------------------------------------------

class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Capture the request body
    final data = options.data;
    if (data is Map) {
      lastBody = Map<String, dynamic>.from(data as Map);
    } else if (data is String) {
      lastBody = jsonDecode(data) as Map<String, dynamic>;
    }

    // Return a minimal 200 OK so the repository treats it as success
    final responseBytes = utf8.encode(jsonEncode({'success': true}));
    return ResponseBody.fromBytes(
      responseBytes,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Factory — builds a WhatsAppRepository wired to the capturing adapter
// ---------------------------------------------------------------------------

Future<(WhatsAppRepository, _CapturingAdapter)> _makeRepo() async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'fake-token',
    'waba_id': 'fake-waba',
    'phone_number_id': 'fake-phone',
    'app_id': 'fake-app',
  });
  final prefs = await SharedPreferences.getInstance();

  final adapter = _CapturingAdapter();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;

  final repo = WhatsAppRepository(dio, prefs);
  return (repo, adapter);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Validity period dropdown options (label → seconds) from the design doc.
const Map<String, int> _validityOptions = {
  '30 seconds': 30,
  '1 minute': 60,
  '2 minutes': 120,
  '5 minutes': 300,
  '10 minutes': 600,
  '15 minutes': 900,
  '30 minutes': 1800,
  '1 hour': 3600,
  '3 hours': 10800,
  '6 hours': 21600,
  '12 hours': 43200,
  '24 hours': 86400,
};

const List<String> _deliveryTypes = ['ZERO_TAP', 'ONE_TAP', 'COPY_CODE'];
const List<String> _autoFillTypes = ['ZERO_TAP', 'ONE_TAP'];

T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

/// Generates a list of 1–5 random AppEntry objects.
List<AppEntry> _randomEntries(Random r, {int? count}) {
  final n = count ?? (1 + r.nextInt(5));
  return List.generate(
    n,
    (i) => AppEntry(
      packageName: 'com.example.pkg${r.nextInt(100000)}',
      // Exactly 11 chars — pad/truncate to satisfy the constraint
      signatureHash: 'SIG${r.nextInt(100000000).toString().padLeft(8, '0')}'.substring(0, 11),
    ),
  );
}

/// Runs [body] [iterations] times with the same [rng].
Future<void> forAll(
  int iterations,
  Random rng,
  Future<void> Function(Random r) body,
) async {
  for (var i = 0; i < iterations; i++) {
    await body(rng);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const iterations = 100;
  // Fixed seed for reproducibility.
  final rng = Random(42);

  // -------------------------------------------------------------------------
  // Property 3 — Validity period toggle OFF omits TTL from payload
  // -------------------------------------------------------------------------
  group('Property 3 — validity toggle OFF omits message_send_ttl_seconds', () {
    test(
      'P3: AUTHENTICATION payload has no message_send_ttl_seconds when '
      'messageSendTtlSeconds is null',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'auth_tmpl_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            messageSendTtlSeconds: null, // toggle OFF
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          expect(
            payload.containsKey('message_send_ttl_seconds'),
            isFalse,
            reason: 'message_send_ttl_seconds must be absent when toggle is OFF',
          );
        });
      },
    );

    test(
      'P3: UTILITY payload has no message_send_ttl_seconds when '
      'messageSendTtlSeconds is null',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'util_tmpl_${r.nextInt(9999)}',
            category: 'UTILITY',
            language: 'en_US',
            body: 'Utility body',
            messageSendTtlSeconds: null, // toggle OFF
          );

          final payload = adapter.lastBody!;
          expect(
            payload.containsKey('message_send_ttl_seconds'),
            isFalse,
            reason: 'message_send_ttl_seconds must be absent for UTILITY when toggle is OFF',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 4 — Validity period value matches selected duration in seconds
  // -------------------------------------------------------------------------
  group('Property 4 — message_send_ttl_seconds matches selected dropdown value', () {
    test(
      'P4: AUTHENTICATION payload message_send_ttl_seconds equals the '
      'seconds value of the selected dropdown option',
      () async {
        final optionEntries = _validityOptions.entries.toList();
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final option = optionEntries[r.nextInt(optionEntries.length)];

          await repo.createTemplate(
            name: 'auth_ttl_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            messageSendTtlSeconds: option.value,
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          expect(
            payload['message_send_ttl_seconds'],
            equals(option.value),
            reason: '"${option.key}" must produce ${option.value} seconds in payload',
          );
        });
      },
    );

    test(
      'P4: UTILITY payload message_send_ttl_seconds equals the '
      'seconds value of the selected dropdown option',
      () async {
        final optionEntries = _validityOptions.entries.toList();
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final option = optionEntries[r.nextInt(optionEntries.length)];

          await repo.createTemplate(
            name: 'util_ttl_${r.nextInt(9999)}',
            category: 'UTILITY',
            language: 'en_US',
            body: 'Utility body',
            messageSendTtlSeconds: option.value,
          );

          final payload = adapter.lastBody!;
          expect(
            payload['message_send_ttl_seconds'],
            equals(option.value),
            reason: '"${option.key}" must produce ${option.value} seconds in UTILITY payload',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 8 — All configured app entries appear in submission payload
  // -------------------------------------------------------------------------
  group('Property 8 — all app entries appear in OTP button app array', () {
    test(
      'P8: every AppEntry in the input list appears in the payload '
      'app array with correct package_name and signature_hash, '
      'in the same order, for ZERO_TAP and ONE_TAP',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final deliveryType = _pick(r, _autoFillTypes);
          final entries = _randomEntries(r);

          await repo.createTemplate(
            name: 'auth_app_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: deliveryType,
            appEntries: entries,
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final buttons = buttonsComponent['buttons'] as List<dynamic>;
          final otpButton = buttons.first as Map<String, dynamic>;

          expect(
            otpButton.containsKey('app'),
            isTrue,
            reason: 'app array must be present for $deliveryType',
          );

          final appArray = otpButton['app'] as List<dynamic>;
          expect(
            appArray.length,
            equals(entries.length),
            reason: 'app array length must match number of configured entries',
          );

          for (var i = 0; i < entries.length; i++) {
            final appItem = appArray[i] as Map<String, dynamic>;
            expect(
              appItem['package_name'],
              equals(entries[i].packageName),
              reason: 'package_name at index $i must match input',
            );
            expect(
              appItem['signature_hash'],
              equals(entries[i].signatureHash),
              reason: 'signature_hash at index $i must match input',
            );
          }
        });
      },
    );

    test(
      'P8: COPY_CODE delivery type produces no app array in payload',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'auth_copy_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: 'COPY_CODE',
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final buttons = buttonsComponent['buttons'] as List<dynamic>;
          final otpButton = buttons.first as Map<String, dynamic>;

          expect(
            otpButton.containsKey('app'),
            isFalse,
            reason: 'app array must be absent for COPY_CODE',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 9 — Security recommendation flag matches checkbox state
  // -------------------------------------------------------------------------
  group('Property 9 — add_security_recommendation in BODY matches checkbox', () {
    test(
      'P9: BODY component add_security_recommendation equals the '
      'addSecurityRecommendation parameter for any bool value',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final secFlag = r.nextBool();

          await repo.createTemplate(
            name: 'auth_sec_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: secFlag,
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final bodyComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BODY',
          ) as Map<String, dynamic>;

          expect(
            bodyComponent['add_security_recommendation'],
            equals(secFlag),
            reason: 'add_security_recommendation must equal checkbox state ($secFlag)',
          );
        });
      },
    );

    test(
      'P9: add_security_recommendation defaults to false when parameter is null',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'auth_sec_null_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: null, // not provided
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final bodyComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BODY',
          ) as Map<String, dynamic>;

          expect(
            bodyComponent['add_security_recommendation'],
            equals(false),
            reason: 'add_security_recommendation must default to false when null',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 10 — Code expiration minutes matches input when expiry enabled
  // -------------------------------------------------------------------------
  group('Property 10 — code_expiration_minutes in OTP button matches input', () {
    test(
      'P10: OTP button code_expiration_minutes equals the configured '
      'codeExpirationMinutes value when addExpiryTime is true',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final expiryMinutes = 1 + r.nextInt(120); // 1–120 minutes

          await repo.createTemplate(
            name: 'auth_exp_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: true,
            codeExpirationMinutes: expiryMinutes,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final otpButton =
              (buttonsComponent['buttons'] as List<dynamic>).first as Map<String, dynamic>;

          expect(
            otpButton['code_expiration_minutes'],
            equals(expiryMinutes),
            reason: 'code_expiration_minutes must equal input value $expiryMinutes',
          );
        });
      },
    );

    test(
      'P10: OTP button has no code_expiration_minutes when addExpiryTime is false',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'auth_noexp_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: _pick(r, _deliveryTypes),
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
            codeExpirationMinutes: 30, // provided but should be ignored
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final otpButton =
              (buttonsComponent['buttons'] as List<dynamic>).first as Map<String, dynamic>;

          expect(
            otpButton.containsKey('code_expiration_minutes'),
            isFalse,
            reason: 'code_expiration_minutes must be absent when addExpiryTime is false',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 14 — Auth payload contains only BODY and BUTTONS components
  // -------------------------------------------------------------------------
  group('Property 14 — AUTHENTICATION components array contains only BODY and BUTTONS', () {
    test(
      'P14: for any AuthFormState, the components array must contain '
      'exactly one BODY and one BUTTONS component, and no HEADER or FOOTER',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final deliveryType = _pick(r, _deliveryTypes);

          await repo.createTemplate(
            name: 'auth_comp_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            // Provide all optional fields to exercise full code paths
            header: 'Some header text',
            footer: 'Some footer',
            buttons: [
              {'type': 'QUICK_REPLY', 'text': 'Yes'},
            ],
            messageSendTtlSeconds: r.nextBool() ? 600 : null,
            codeDeliveryType: deliveryType,
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: r.nextBool(),
            codeExpirationMinutes: 10,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final types = components
              .map((c) => (c as Map<String, dynamic>)['type'] as String)
              .toList();

          // Must contain exactly BODY and BUTTONS
          expect(
            types,
            containsAll(['BODY', 'BUTTONS']),
            reason: 'components must include BODY and BUTTONS',
          );
          expect(
            types.length,
            equals(2),
            reason: 'components must contain exactly 2 items (BODY + BUTTONS)',
          );

          // Must NOT contain HEADER or FOOTER
          expect(
            types.contains('HEADER'),
            isFalse,
            reason: 'AUTHENTICATION payload must not contain HEADER',
          );
          expect(
            types.contains('FOOTER'),
            isFalse,
            reason: 'AUTHENTICATION payload must not contain FOOTER',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 15 — OTP button otp_type matches delivery type selection
  // -------------------------------------------------------------------------
  group('Property 15 — OTP button otp_type matches codeDeliveryType', () {
    test(
      'P15: for any delivery type selection, the otp_type field in the '
      'OTP button equals the selected delivery type string',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();
          final deliveryType = _pick(r, _deliveryTypes);

          await repo.createTemplate(
            name: 'auth_otp_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: deliveryType,
            appEntries: _randomEntries(r),
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final otpButton =
              (buttonsComponent['buttons'] as List<dynamic>).first as Map<String, dynamic>;

          expect(
            otpButton['otp_type'],
            equals(deliveryType),
            reason: 'otp_type must equal selected delivery type "$deliveryType"',
          );
          expect(
            otpButton['type'],
            equals('OTP'),
            reason: 'button type must be OTP',
          );
        });
      },
    );

    test(
      'P15: null codeDeliveryType defaults otp_type to COPY_CODE',
      () async {
        await forAll(iterations, rng, (r) async {
          final (repo, adapter) = await _makeRepo();

          await repo.createTemplate(
            name: 'auth_default_otp_${r.nextInt(9999)}',
            category: 'AUTHENTICATION',
            language: 'en_US',
            body: 'OTP body',
            codeDeliveryType: null, // not provided
            addSecurityRecommendation: r.nextBool(),
            addExpiryTime: false,
          );

          final payload = adapter.lastBody!;
          final components = payload['components'] as List<dynamic>;
          final buttonsComponent = components.firstWhere(
            (c) => (c as Map)['type'] == 'BUTTONS',
          ) as Map<String, dynamic>;
          final otpButton =
              (buttonsComponent['buttons'] as List<dynamic>).first as Map<String, dynamic>;

          expect(
            otpButton['otp_type'],
            equals('COPY_CODE'),
            reason: 'otp_type must default to COPY_CODE when codeDeliveryType is null',
          );
        });
      },
    );
  });
}

