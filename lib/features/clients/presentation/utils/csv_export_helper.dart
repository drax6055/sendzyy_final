import 'dart:convert';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:csv/csv.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';

class CsvExportHelper {
  /// Converts a list of [ClientModel] items to CSV and triggers download.
  static Future<void> downloadClientsCsv(List<ClientModel> clients, String fileName) async {
    final List<List<dynamic>> rows = [
      ['Name', 'Mobile Number', 'Company', 'Email', 'Venue', 'Remark', 'Added On'],
    ];

    for (final c in clients) {
      final dateStr =
          '${c.createdAt.day.toString().padLeft(2, '0')}/${c.createdAt.month.toString().padLeft(2, '0')}/${c.createdAt.year}';
      rows.add([
        c.name,
        c.mobileNumber,
        c.companyName ?? '',
        c.emailId ?? '',
        c.venue ?? '',
        c.remark ?? '',
        dateStr,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    // Include UTF-8 BOM (\uFEFF) so Excel opens UTF-8 encoded CSV files correctly
    final bytes = utf8.encode('\uFEFF$csvString');
    final finalFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';

    await webDownloadBytes(bytes, finalFileName, mimeType: 'text/csv;charset=utf-8');
  }
}
