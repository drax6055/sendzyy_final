// Feature: template-category-utility-authentication, Property 17
// Property 17: Media file validator enforces size and format constraints
// Validates: Requirements 11.8, 11.9, 11.10

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iFloraBuzz/core/utils/media_validator.dart';

// ---------------------------------------------------------------------------
// Helpers — build a PlatformFile with a given name and size (bytes)
// ---------------------------------------------------------------------------

PlatformFile _makeFile(String name, int sizeBytes) {
  return PlatformFile(name: name, size: sizeBytes);
}

// ---------------------------------------------------------------------------
// Property-based test helpers
// ---------------------------------------------------------------------------

/// Runs [body] for [iterations] random seeds, collecting any failures.
void forAll(
  int iterations,
  Random rng,
  void Function(Random r) body,
) {
  for (var i = 0; i < iterations; i++) {
    body(rng);
  }
}

// ---------------------------------------------------------------------------
// Constants mirroring MediaValidator internals
// ---------------------------------------------------------------------------

const int _imageSizeLimit = 5 * 1024 * 1024; // 5 MB
const int _videoSizeLimit = 16 * 1024 * 1024; // 16 MB
const int _documentSizeLimit = 100 * 1024 * 1024; // 100 MB

const List<String> _validImageExts = ['jpg', 'jpeg', 'png'];
const List<String> _validVideoExts = ['mp4'];
const List<String> _validDocumentExts = ['pdf'];

// A pool of invalid extensions for each media type
const List<String> _invalidImageExts = ['gif', 'bmp', 'webp', 'tiff', 'svg', 'mp4', 'pdf', 'txt', 'exe'];
const List<String> _invalidVideoExts = ['avi', 'mov', 'mkv', 'wmv', 'flv', 'jpg', 'pdf', 'txt'];
const List<String> _invalidDocumentExts = ['doc', 'docx', 'txt', 'xls', 'jpg', 'mp4', 'odt'];

// ---------------------------------------------------------------------------
// Generator helpers
// ---------------------------------------------------------------------------

/// Picks a random element from [list].
T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

/// Generates a random file size in [0, maxBytes].
int _randSize(Random r, int maxBytes) => r.nextInt(maxBytes + 1);

void main() {
  // Use a fixed seed so failures are reproducible; change to Random() for
  // true randomness across runs.
  final rng = Random(42);
  const iterations = 100;

  // -------------------------------------------------------------------------
  // Property 17a — Image validator
  // -------------------------------------------------------------------------
  group('MediaValidator.validateImage', () {
    test(
      'P17a: valid image (correct ext + size ≤ 5 MB) → returns null',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validImageExts);
          // size in [0, 5 MB]
          final size = _randSize(r, _imageSizeLimit);
          final file = _makeFile('photo.$ext', size);
          final result = MediaValidator.validateImage(file);
          expect(
            result,
            isNull,
            reason: 'Expected null for valid image: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17a: image with invalid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _invalidImageExts);
          // size can be anything — extension alone should trigger rejection
          final size = _randSize(r, _imageSizeLimit);
          final file = _makeFile('photo.$ext', size);
          final result = MediaValidator.validateImage(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for invalid image ext=$ext',
          );
        });
      },
    );

    test(
      'P17a: image exceeding 5 MB with valid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validImageExts);
          // size in (_imageSizeLimit, _imageSizeLimit * 3]
          final size = _imageSizeLimit + 1 + r.nextInt(_imageSizeLimit * 2);
          final file = _makeFile('photo.$ext', size);
          final result = MediaValidator.validateImage(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for oversized image: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17a: image at exactly the 5 MB boundary → returns null',
      () {
        for (final ext in _validImageExts) {
          final file = _makeFile('photo.$ext', _imageSizeLimit);
          expect(
            MediaValidator.validateImage(file),
            isNull,
            reason: 'Expected null at exact 5 MB boundary for ext=$ext',
          );
        }
      },
    );

    test(
      'P17a: image 1 byte over 5 MB → returns non-null error',
      () {
        for (final ext in _validImageExts) {
          final file = _makeFile('photo.$ext', _imageSizeLimit + 1);
          expect(
            MediaValidator.validateImage(file),
            isNotNull,
            reason: 'Expected error for 1 byte over 5 MB, ext=$ext',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 17b — Video validator
  // -------------------------------------------------------------------------
  group('MediaValidator.validateVideo', () {
    test(
      'P17b: valid video (correct ext + size ≤ 16 MB) → returns null',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validVideoExts);
          final size = _randSize(r, _videoSizeLimit);
          final file = _makeFile('clip.$ext', size);
          final result = MediaValidator.validateVideo(file);
          expect(
            result,
            isNull,
            reason: 'Expected null for valid video: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17b: video with invalid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _invalidVideoExts);
          final size = _randSize(r, _videoSizeLimit);
          final file = _makeFile('clip.$ext', size);
          final result = MediaValidator.validateVideo(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for invalid video ext=$ext',
          );
        });
      },
    );

    test(
      'P17b: video exceeding 16 MB with valid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validVideoExts);
          final size = _videoSizeLimit + 1 + r.nextInt(_videoSizeLimit * 2);
          final file = _makeFile('clip.$ext', size);
          final result = MediaValidator.validateVideo(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for oversized video: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17b: video at exactly the 16 MB boundary → returns null',
      () {
        for (final ext in _validVideoExts) {
          final file = _makeFile('clip.$ext', _videoSizeLimit);
          expect(
            MediaValidator.validateVideo(file),
            isNull,
            reason: 'Expected null at exact 16 MB boundary for ext=$ext',
          );
        }
      },
    );

    test(
      'P17b: video 1 byte over 16 MB → returns non-null error',
      () {
        for (final ext in _validVideoExts) {
          final file = _makeFile('clip.$ext', _videoSizeLimit + 1);
          expect(
            MediaValidator.validateVideo(file),
            isNotNull,
            reason: 'Expected error for 1 byte over 16 MB, ext=$ext',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 17c — Document validator
  // -------------------------------------------------------------------------
  group('MediaValidator.validateDocument', () {
    test(
      'P17c: valid document (correct ext + size ≤ 100 MB) → returns null',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validDocumentExts);
          final size = _randSize(r, _documentSizeLimit);
          final file = _makeFile('doc.$ext', size);
          final result = MediaValidator.validateDocument(file);
          expect(
            result,
            isNull,
            reason: 'Expected null for valid document: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17c: document with invalid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _invalidDocumentExts);
          final size = _randSize(r, _documentSizeLimit);
          final file = _makeFile('doc.$ext', size);
          final result = MediaValidator.validateDocument(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for invalid document ext=$ext',
          );
        });
      },
    );

    test(
      'P17c: document exceeding 100 MB with valid extension → returns non-null error',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, _validDocumentExts);
          final size = _documentSizeLimit + 1 + r.nextInt(50 * 1024 * 1024);
          final file = _makeFile('doc.$ext', size);
          final result = MediaValidator.validateDocument(file);
          expect(
            result,
            isNotNull,
            reason: 'Expected error for oversized document: ext=$ext, size=$size',
          );
        });
      },
    );

    test(
      'P17c: document at exactly the 100 MB boundary → returns null',
      () {
        for (final ext in _validDocumentExts) {
          final file = _makeFile('doc.$ext', _documentSizeLimit);
          expect(
            MediaValidator.validateDocument(file),
            isNull,
            reason: 'Expected null at exact 100 MB boundary for ext=$ext',
          );
        }
      },
    );

    test(
      'P17c: document 1 byte over 100 MB → returns non-null error',
      () {
        for (final ext in _validDocumentExts) {
          final file = _makeFile('doc.$ext', _documentSizeLimit + 1);
          expect(
            MediaValidator.validateDocument(file),
            isNotNull,
            reason: 'Expected error for 1 byte over 100 MB, ext=$ext',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 17d — Cross-type: wrong validator for file type → always rejects
  // -------------------------------------------------------------------------
  group('MediaValidator cross-type rejection', () {
    test(
      'P17d: image validator rejects video/document extensions',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, [..._validVideoExts, ..._validDocumentExts]);
          final size = _randSize(r, _imageSizeLimit);
          final file = _makeFile('file.$ext', size);
          expect(
            MediaValidator.validateImage(file),
            isNotNull,
            reason: 'Image validator should reject ext=$ext',
          );
        });
      },
    );

    test(
      'P17d: video validator rejects image/document extensions',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, [..._validImageExts, ..._validDocumentExts]);
          final size = _randSize(r, _videoSizeLimit);
          final file = _makeFile('file.$ext', size);
          expect(
            MediaValidator.validateVideo(file),
            isNotNull,
            reason: 'Video validator should reject ext=$ext',
          );
        });
      },
    );

    test(
      'P17d: document validator rejects image/video extensions',
      () {
        forAll(iterations, rng, (r) {
          final ext = _pick(r, [..._validImageExts, ..._validVideoExts]);
          final size = _randSize(r, _documentSizeLimit);
          final file = _makeFile('file.$ext', size);
          expect(
            MediaValidator.validateDocument(file),
            isNotNull,
            reason: 'Document validator should reject ext=$ext',
          );
        });
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property 17e — Case-insensitive extension handling
  // -------------------------------------------------------------------------
  group('MediaValidator case-insensitive extensions', () {
    test(
      'P17e: uppercase/mixed-case valid extensions are accepted',
      () {
        final cases = [
          _makeFile('photo.JPG', 1024),
          _makeFile('photo.Jpeg', 1024),
          _makeFile('photo.PNG', 1024),
          _makeFile('clip.MP4', 1024),
          _makeFile('doc.PDF', 1024),
        ];
        expect(MediaValidator.validateImage(cases[0]), isNull);
        expect(MediaValidator.validateImage(cases[1]), isNull);
        expect(MediaValidator.validateImage(cases[2]), isNull);
        expect(MediaValidator.validateVideo(cases[3]), isNull);
        expect(MediaValidator.validateDocument(cases[4]), isNull);
      },
    );
  });
}
