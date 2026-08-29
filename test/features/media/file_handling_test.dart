import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iFloraBuzz/core/utils/media_validator.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';
import 'package:csv/csv.dart';

void main() {
  group('File and Media Handling Tests (Memory Safety)', () {
    test('MediaValidator validates file without bytes (using name and size only)', () {
      final validImage = PlatformFile(
        name: 'sample.png',
        size: 2 * 1024 * 1024, // 2MB
        bytes: null,
        path: '/dummy/path/sample.png',
      );
      expect(MediaValidator.validateImage(validImage), isNull);

      final oversizedImage = PlatformFile(
        name: 'huge.jpg',
        size: 10 * 1024 * 1024, // 10MB > 5MB limit
        bytes: null,
        path: '/dummy/path/huge.jpg',
      );
      expect(MediaValidator.validateImage(oversizedImage), isNotNull);

      final validVideo = PlatformFile(
        name: 'clip.mp4',
        size: 10 * 1024 * 1024, // 10MB < 16MB limit
        bytes: null,
        path: '/dummy/path/clip.mp4',
      );
      expect(MediaValidator.validateVideo(validVideo), isNull);

      final oversizedVideo = PlatformFile(
        name: 'movie.mp4',
        size: 20 * 1024 * 1024, // 20MB > 16MB limit
        bytes: null,
        path: '/dummy/path/movie.mp4',
      );
      expect(MediaValidator.validateVideo(oversizedVideo), isNotNull);

      final validDoc = PlatformFile(
        name: 'report.pdf',
        size: 5 * 1024 * 1024,
        bytes: null,
        path: '/dummy/path/report.pdf',
      );
      expect(MediaValidator.validateDocument(validDoc), isNull);
    });

    test('CSV parsing handles both in-memory bytes and local filesystem safely', () async {
      const csvContent = 'name,mobile,company\nAlice,919876543210,Alpha\nBob,919123456789,Beta';
      
      // Test 1: From bytes (Web)
      final webBytes = utf8.encode(csvContent);
      final webFile = PlatformFile(
        name: 'contacts.csv',
        size: webBytes.length,
        bytes: Uint8List.fromList(webBytes),
      );
      final webRawBytes = webFile.bytes ?? (!kIsWeb && webFile.path != null ? await File(webFile.path!).readAsBytes() : null);
      expect(webRawBytes, isNotNull);
      final webRows = const CsvToListConverter(eol: '\n').convert(utf8.decode(webRawBytes!));
      expect(webRows.length, equals(3));

      // Test 2: From file path (Native Mobile/Desktop)
      final tempFile = File('${Directory.systemTemp.path}/test_contacts.csv');
      await tempFile.writeAsString(csvContent);
      try {
        final mobileFile = PlatformFile(
          name: 'test_contacts.csv',
          size: await tempFile.length(),
          bytes: null,
          path: tempFile.path,
        );
        final mobileRawBytes = mobileFile.bytes ?? (!kIsWeb && mobileFile.path != null ? await File(mobileFile.path!).readAsBytes() : null);
        expect(mobileRawBytes, isNotNull);
        final mobileRows = const CsvToListConverter(eol: '\n').convert(utf8.decode(mobileRawBytes!));
        expect(mobileRows.length, equals(3));
        expect(mobileRows[1][0], equals('Alice'));
        expect(mobileRows[1][1], equals(919876543210));
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('RecipientData parsing from CSV works with normalized phone numbers', () {
      final row = ['919876543210', 'John Doe', 'Welcome', 'Acme'];
      final recipient = RecipientData.fromCsvRow(row);
      expect(recipient.mobileNumber, equals('919876543210'));
      expect(recipient.name, equals('John Doe'));
      expect(RecipientData.normalizeNumber(recipient.mobileNumber), equals('919876543210'));
    });
  });
}
