import 'dart:convert';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';

// Re-export so existing imports of csv_uploader.dart continue to work.
export 'package:iFloraBuzz/features/messages/data/models/recipient_data.dart';

class CsvUploader extends StatelessWidget {
  final Function(List<RecipientData> parsed, {required int invalidCount, required int duplicateCount}) onParsed;

  const CsvUploader({super.key, required this.onParsed});

  void _downloadSample() async {
    const csv = 
        '919876543210,John,Hello,Acme Corp\n'
        '919123456789,Jane,Hi,Example Ltd\n'
        '917890123456,Bob,Hey,Bob Enterprises\n';
    await webDownloadBytes(utf8.encode(csv), 'sample_campaign.csv', mimeType: 'text/csv');
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final content = utf8.decode(result.files.first.bytes!);
        List<List<dynamic>> rows = const CsvToListConverter().convert(content);

        // Skip header row if first cell looks like a label
        final dataRows = rows.where((row) {
          if (row.isEmpty) return false;
          final first = row[0].toString().trim().toLowerCase();
          return first != 'mobile' &&
              first != 'phone' &&
              first != 'number' &&
              first.isNotEmpty;
        }).toList();

        final recipients = dataRows
            .map((row) => RecipientData.fromCsvRow(row))
            .where((r) => r.mobileNumber.isNotEmpty)
            .toList();

        // Filter invalid numbers and deduplicate within the CSV itself
        final seen = <String>{};
        final valid = <RecipientData>[];
        int invalid = 0;
        int internalDuplicates = 0;
        for (final r in recipients) {
          final normalized = RecipientData.normalizeNumber(r.mobileNumber);
          if (normalized == null) {
            invalid++;
            continue;
          }
          if (seen.contains(normalized)) {
            internalDuplicates++;
            continue;
          }
          seen.add(normalized);
          valid.add(RecipientData(
            mobileNumber: normalized,
            name: r.name,
            variables: r.variables,
            fromCsv: true,
          ));
        }

        if (context.mounted) {
          onParsed(valid, invalidCount: invalid, duplicateCount: internalDuplicates);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error parsing CSV: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => _pickFile(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE8F5E9),
              border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    size: 32,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Click to upload CSV file',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Columns: mobile, {{1}}, {{2}}, {{3}}...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'e.g. 919876543210, John, +91..., ABC Co.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _downloadSample,
          child: const Text(
            'Download sample CSV',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
