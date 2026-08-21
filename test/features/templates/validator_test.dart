// Feature: template-category-utility-authentication, Property 18
// Property 18: Text field and button validators enforce all length and format constraints
// Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.11, 11.12

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/core/utils/template_validators.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void forAll(int iterations, Random rng, void Function(Random r) body) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

String _randomString(Random r, int length, {String charset = _alphaNum}) {
  return List.generate(length, (_) => charset[r.nextInt(charset.length)]).join();
}

const String _alphaNum =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';

const String _validNameChars = 'abcdefghijklmnopqrstuvwxyz0123456789_';

const String _invalidNameChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ !@#\$%^&*()-+=[]{}|;:,.<>?/';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rng = Random(42);
  const iterations = 100;

  // =========================================================================
  // Property 18a: validateTemplateName (Requirement 11.1)
  // =========================================================================
  group('P18a: validateTemplateName - Requirement 11.1', () {
    test('valid name (lowercase/digits/underscores, max 512 chars) returns null', () {
      forAll(iterations, rng, (r) {
        final length = 1 + r.nextInt(512);
        final name = _randomString(r, length, charset: _validNameChars);
        expect(
          TemplateValidators.validateTemplateName(name),
          isNull,
          reason: 'Expected null for valid name of length $length',
        );
      });
    });

    test('name exceeding 512 characters returns non-null error', () {
      forAll(iterations, rng, (r) {
        final length = 513 + r.nextInt(200);
        final name = _randomString(r, length, charset: _validNameChars);
        expect(
          TemplateValidators.validateTemplateName(name),
          isNotNull,
          reason: 'Expected error for name of length $length (> 512)',
        );
      });
    });

    test('name with invalid characters returns non-null error', () {
      forAll(iterations, rng, (r) {
        final invalidChar =
            _invalidNameChars[r.nextInt(_invalidNameChars.length)];
        final prefix =
            _randomString(r, 1 + r.nextInt(10), charset: _validNameChars);
        final name = '${prefix}${invalidChar}';
        expect(
          TemplateValidators.validateTemplateName(name),
          isNotNull,
          reason: 'Expected error for name containing "$invalidChar"',
        );
      });
    });

    test('empty or null name returns non-null error', () {
      expect(TemplateValidators.validateTemplateName(''), isNotNull);
      expect(TemplateValidators.validateTemplateName(null), isNotNull);
    });

    test('name at exactly 512 characters returns null', () {
      final name = _randomString(rng, 512, charset: _validNameChars);
      expect(TemplateValidators.validateTemplateName(name), isNull);
    });

    test('name at 513 characters returns non-null error', () {
      final name = _randomString(rng, 513, charset: _validNameChars);
      expect(TemplateValidators.validateTemplateName(name), isNotNull);
    });
  });

  // =========================================================================
  // Property 18b: validateBodyText (Requirement 11.2)
  // =========================================================================
  group('P18b: validateBodyText - Requirement 11.2', () {
    test('body text up to 1024 chars returns null', () {
      forAll(iterations, rng, (r) {
        final length = 1 + r.nextInt(1024);
        final body = _randomString(r, length);
        expect(
          TemplateValidators.validateBodyText(body),
          isNull,
          reason: 'Expected null for body of length $length',
        );
      });
    });

    test('body text exceeding 1024 chars returns non-null error', () {
      forAll(iterations, rng, (r) {
        final length = 1025 + r.nextInt(500);
        final body = _randomString(r, length);
        expect(
          TemplateValidators.validateBodyText(body),
          isNotNull,
          reason: 'Expected error for body of length $length (> 1024)',
        );
      });
    });

    test('empty or null body returns non-null error', () {
      expect(TemplateValidators.validateBodyText(''), isNotNull);
      expect(TemplateValidators.validateBodyText(null), isNotNull);
    });

    test('body at exactly 1024 chars returns null', () {
      final body = _randomString(rng, 1024);
      expect(TemplateValidators.validateBodyText(body), isNull);
    });

    test('body at 1025 chars returns non-null error', () {
      final body = _randomString(rng, 1025);
      expect(TemplateValidators.validateBodyText(body), isNotNull);
    });
  });

  // =========================================================================
  // Property 18c: validateHeaderText (Requirement 11.3)
  // =========================================================================
  group('P18c: validateHeaderText - Requirement 11.3', () {
    const safeChars = 'abcdefghijklmnopqrstuvwxyz0123456789 ';

    test('valid header (max 60 chars, no emoji, no asterisk) returns null', () {
      forAll(iterations, rng, (r) {
        final length = 1 + r.nextInt(60);
        final header = _randomString(r, length, charset: safeChars);
        expect(
          TemplateValidators.validateHeaderText(header),
          isNull,
          reason: 'Expected null for valid header of length $length',
        );
      });
    });

    test('header exceeding 60 chars returns non-null error', () {
      forAll(iterations, rng, (r) {
        final length = 61 + r.nextInt(100);
        final header = _randomString(r, length, charset: safeChars);
        expect(
          TemplateValidators.validateHeaderText(header),
          isNotNull,
          reason: 'Expected error for header of length $length (> 60)',
        );
      });
    });

    test('header containing asterisk returns non-null error', () {
      forAll(iterations, rng, (r) {
        final prefix =
            _randomString(r, r.nextInt(30), charset: safeChars);
        final header = '${prefix}*suffix';
        expect(
          TemplateValidators.validateHeaderText(header),
          isNotNull,
          reason: 'Expected error for header containing asterisk',
        );
      });
    });

    test('header containing emoji returns non-null error', () {
      const emojiHeaders = [
        'Hello \u{1F600}',
        'Welcome \u{1F389}',
        'Order \u{1F4E6} confirmed',
        '\u{1F525} Hot deal',
      ];
      for (final h in emojiHeaders) {
        expect(
          TemplateValidators.validateHeaderText(h),
          isNotNull,
          reason: 'Expected error for header with emoji',
        );
      }
    });

    test('empty or null header returns null (header is optional)', () {
      expect(TemplateValidators.validateHeaderText(''), isNull);
      expect(TemplateValidators.validateHeaderText(null), isNull);
    });

    test('header at exactly 60 chars returns null', () {
      final header = _randomString(rng, 60, charset: safeChars);
      expect(TemplateValidators.validateHeaderText(header), isNull);
    });

    test('header at 61 chars returns non-null error', () {
      final header = _randomString(rng, 61, charset: safeChars);
      expect(TemplateValidators.validateHeaderText(header), isNotNull);
    });
  });

  // =========================================================================
  // Property 18d: validateFooterText (Requirement 11.4)
  // =========================================================================
  group('P18d: validateFooterText - Requirement 11.4', () {
    test('valid footer (max 60 chars) returns null', () {
      forAll(iterations, rng, (r) {
        final length = 1 + r.nextInt(60);
        final footer = _randomString(r, length);
        expect(
          TemplateValidators.validateFooterText(footer),
          isNull,
          reason: 'Expected null for footer of length $length',
        );
      });
    });

    test('footer exceeding 60 chars returns non-null error', () {
      forAll(iterations, rng, (r) {
        final length = 61 + r.nextInt(100);
        final footer = _randomString(r, length);
        expect(
          TemplateValidators.validateFooterText(footer),
          isNotNull,
          reason: 'Expected error for footer of length $length (> 60)',
        );
      });
    });

    test('empty or null footer returns null (footer is optional)', () {
      expect(TemplateValidators.validateFooterText(''), isNull);
      expect(TemplateValidators.validateFooterText(null), isNull);
    });

    test('footer at exactly 60 chars returns null', () {
      final footer = _randomString(rng, 60);
      expect(TemplateValidators.validateFooterText(footer), isNull);
    });

    test('footer at 61 chars returns non-null error', () {
      final footer = _randomString(rng, 61);
      expect(TemplateValidators.validateFooterText(footer), isNotNull);
    });
  });

  // =========================================================================
  // Property 18e: validateButtonLabel (Requirement 11.5)
  // =========================================================================
  group('P18e: validateButtonLabel - Requirement 11.5', () {
    test('valid label (max 25 chars) returns null', () {
      forAll(iterations, rng, (r) {
        final length = 1 + r.nextInt(25);
        final label = _randomString(r, length);
        expect(
          TemplateValidators.validateButtonLabel(label),
          isNull,
          reason: 'Expected null for label of length $length',
        );
      });
    });

    test('label exceeding 25 chars returns non-null error', () {
      forAll(iterations, rng, (r) {
        final length = 26 + r.nextInt(50);
        final label = _randomString(r, length);
        expect(
          TemplateValidators.validateButtonLabel(label),
          isNotNull,
          reason: 'Expected error for label of length $length (> 25)',
        );
      });
    });

    test('empty or null label returns non-null error', () {
      expect(TemplateValidators.validateButtonLabel(''), isNotNull);
      expect(TemplateValidators.validateButtonLabel(null), isNotNull);
    });

    test('label at exactly 25 chars returns null', () {
      final label = _randomString(rng, 25);
      expect(TemplateValidators.validateButtonLabel(label), isNull);
    });

    test('label at 26 chars returns non-null error', () {
      final label = _randomString(rng, 26);
      expect(TemplateValidators.validateButtonLabel(label), isNotNull);
    });
  });

  // =========================================================================
  // Property 18f: validateUrl (Requirement 11.6)
  // =========================================================================
  group('P18f: validateUrl - Requirement 11.6', () {
    test('valid http/https URLs return null', () {
      const validUrls = [
        'https://example.com',
        'http://example.com',
        'https://www.example.com/path',
        'https://sub.domain.co.uk/page',
        'http://localhost:8080',
      ];
      for (final url in validUrls) {
        expect(
          TemplateValidators.validateUrl(url),
          isNull,
          reason: 'Expected null for valid URL: "$url"',
        );
      }
    });

    test('URLs without http/https scheme return non-null error', () {
      const invalidUrls = [
        'ftp://example.com',
        'example.com',
        'www.example.com',
        'just-a-string',
        '//example.com',
      ];
      for (final url in invalidUrls) {
        expect(
          TemplateValidators.validateUrl(url),
          isNotNull,
          reason: 'Expected error for URL without http/https: "$url"',
        );
      }
    });

    test('empty or null URL returns non-null error', () {
      expect(TemplateValidators.validateUrl(''), isNotNull);
      expect(TemplateValidators.validateUrl(null), isNotNull);
    });

    test('random valid https URLs return null', () {
      forAll(iterations, rng, (r) {
        final slug = _randomString(r, 3 + r.nextInt(15),
            charset: 'abcdefghijklmnopqrstuvwxyz');
        final url = 'https://$slug.com';
        expect(
          TemplateValidators.validateUrl(url),
          isNull,
          reason: 'Expected null for URL: "$url"',
        );
      });
    });
  });

  // =========================================================================
  // Property 18g: validatePhoneNumber (Requirement 11.7)
  // =========================================================================
  group('P18g: validatePhoneNumber - Requirement 11.7', () {
    test('phone number starting with + returns null', () {
      const validNumbers = [
        '+1234567890',
        '+919876543210',
        '+447911123456',
        '+1',
      ];
      for (final num in validNumbers) {
        expect(
          TemplateValidators.validatePhoneNumber(num),
          isNull,
          reason: 'Expected null for phone: "$num"',
        );
      }
    });

    test('phone number not starting with + returns non-null error', () {
      forAll(iterations, rng, (r) {
        final digits =
            _randomString(r, 7 + r.nextInt(6), charset: '0123456789');
        expect(
          TemplateValidators.validatePhoneNumber(digits),
          isNotNull,
          reason: 'Expected error for phone without +: "$digits"',
        );
      });
    });

    test('empty or null phone returns non-null error', () {
      expect(TemplateValidators.validatePhoneNumber(''), isNotNull);
      expect(TemplateValidators.validatePhoneNumber(null), isNotNull);
    });

    test('random phone numbers starting with + return null', () {
      forAll(iterations, rng, (r) {
        final digits =
            _randomString(r, 7 + r.nextInt(6), charset: '0123456789');
        final phone = '+$digits';
        expect(
          TemplateValidators.validatePhoneNumber(phone),
          isNull,
          reason: 'Expected null for phone: "$phone"',
        );
      });
    });
  });

  // =========================================================================
  // Property 18h: validateButtonCount (Requirement 11.11)
  // =========================================================================
  group('P18h: validateButtonCount - Requirement 11.11', () {
    test('count up to 10 returns null', () {
      for (var count = 0; count <= 10; count++) {
        expect(
          TemplateValidators.validateButtonCount(count),
          isNull,
          reason: 'Expected null for count=$count',
        );
      }
    });

    test('count greater than 10 returns non-null error', () {
      forAll(iterations, rng, (r) {
        final count = 11 + r.nextInt(20);
        expect(
          TemplateValidators.validateButtonCount(count),
          isNotNull,
          reason: 'Expected error for count=$count (> 10)',
        );
      });
    });

    test('boundary: count 10 returns null; count 11 returns non-null error', () {
      expect(TemplateValidators.validateButtonCount(10), isNull);
      expect(TemplateValidators.validateButtonCount(11), isNotNull);
    });
  });

  // =========================================================================
  // Property 18i: validateButtonMix (Requirement 11.12)
  // =========================================================================
  group('P18i: validateButtonMix - Requirement 11.12', () {
    List<Map<String, dynamic>> makeButtons(int quickReplies, int ctas) {
      return [
        ...List.generate(
            quickReplies, (_) => {'type': 'QUICK_REPLY', 'text': 'Reply'}),
        ...List.generate(ctas,
            (_) => {'type': 'URL', 'text': 'Visit', 'url': 'https://x.com'}),
      ];
    }

    test('only QUICK_REPLY buttons (no CTAs) returns null regardless of count', () {
      forAll(iterations, rng, (r) {
        final count = r.nextInt(11);
        final buttons = makeButtons(count, 0);
        expect(
          TemplateValidators.validateButtonMix(buttons),
          isNull,
          reason: 'Expected null for $count quick replies with no CTAs',
        );
      });
    });

    test('only CTA buttons (no QUICK_REPLY) returns null', () {
      forAll(iterations, rng, (r) {
        final count = r.nextInt(11);
        final buttons = makeButtons(0, count);
        expect(
          TemplateValidators.validateButtonMix(buttons),
          isNull,
          reason: 'Expected null for $count CTAs with no quick replies',
        );
      });
    });

    test('mixed: up to 3 QUICK_REPLY with CTAs returns null', () {
      forAll(iterations, rng, (r) {
        final qr = 1 + r.nextInt(3); // 1-3
        final cta = 1 + r.nextInt(3); // 1-3
        final buttons = makeButtons(qr, cta);
        expect(
          TemplateValidators.validateButtonMix(buttons),
          isNull,
          reason: 'Expected null for $qr quick replies + $cta CTAs',
        );
      });
    });

    test('mixed: more than 3 QUICK_REPLY with CTAs returns non-null error', () {
      forAll(iterations, rng, (r) {
        final qr = 4 + r.nextInt(4); // 4-7
        final cta = 1 + r.nextInt(3); // 1-3
        final buttons = makeButtons(qr, cta);
        expect(
          TemplateValidators.validateButtonMix(buttons),
          isNotNull,
          reason: 'Expected error for $qr quick replies + $cta CTAs',
        );
      });
    });

    test('boundary: exactly 3 QUICK_REPLY + 1 CTA returns null', () {
      final buttons = makeButtons(3, 1);
      expect(TemplateValidators.validateButtonMix(buttons), isNull);
    });

    test('boundary: 4 QUICK_REPLY + 1 CTA returns non-null error', () {
      final buttons = makeButtons(4, 1);
      expect(TemplateValidators.validateButtonMix(buttons), isNotNull);
    });

    test('empty button list returns null', () {
      expect(TemplateValidators.validateButtonMix([]), isNull);
    });
  });
}
