import 'dart:convert';
import 'package:iFloraBuzz/core/utils/web_helper.dart';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';

class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key});

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  List<ClientModel>? _preview;
  String? _error;
  bool _isImporting = false;

  void _downloadSample() async {
    const csv = 'name,mobile,company,email,venue,remark\n'
        'John Doe,919876543210,Acme Corp,john@acme.com,Main Street Store,VIP customer\n'
        'Jane Smith,919123456789,,jane@example.com,Wedding Expo 2025,\n'
        'Bob Kumar,917890123456,Bob Enterprises,,City Mall,Referred by John\n';
    await webDownloadBytes(utf8.encode(csv), 'sample_clients.csv', mimeType: 'text/csv');
  }

  Future<void> _pickFile() async {
    setState(() { _error = null; _preview = null; });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final content = String.fromCharCodes(result.files.single.bytes!);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.isEmpty) throw Exception('CSV is empty');

      // Detect header row
      final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final nameIdx = _findCol(header, ['name']);
      final mobileIdx = _findCol(header, ['mobile', 'phone', 'mobilenumber', 'mobile_number', 'mobile number']);
      final companyIdx = _findCol(header, ['company', 'companyname', 'company_name', 'company name']);
      final emailIdx = _findCol(header, ['email', 'emailid', 'email_id', 'email id']);
      final venueIdx = _findCol(header, ['venue']);
      final remarkIdx = _findCol(header, ['remark', 'remarks', 'note', 'notes']);

      if (nameIdx == -1 || mobileIdx == -1) {
        throw Exception('CSV must have "name" and "mobile" columns');
      }

      final clients = <ClientModel>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final name = _cell(row, nameIdx);
        final mobile = _cell(row, mobileIdx);
        final rawVenue = _cell(row, venueIdx);
        if (name.isEmpty || mobile.isEmpty) continue;
        final venue = rawVenue.isEmpty ? '-' : rawVenue;
        clients.add(ClientModel(
          id: '',
          tenantId: '',
          name: name,
          mobileNumber: mobile,
          companyName: companyIdx != -1 ? _cell(row, companyIdx).nullIfEmpty : null,
          emailId: emailIdx != -1 ? _cell(row, emailIdx).nullIfEmpty : null,
          venue: venue,
          remark: remarkIdx != -1 ? _cell(row, remarkIdx).nullIfEmpty : null,
          createdAt: DateTime.now(),
        ));
      }

      if (clients.isEmpty) throw Exception('No valid rows found in CSV');
      setState(() => _preview = clients);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  int _findCol(List<String> header, List<String> keys) {
    for (final key in keys) {
      final idx = header.indexWhere((h) => h.replaceAll(' ', '').replaceAll('_', '') == key.replaceAll(' ', '').replaceAll('_', ''));
      if (idx != -1) return idx;
    }
    return -1;
  }

  String _cell(List row, int idx) =>
      (idx >= 0 && idx < row.length) ? row[idx].toString().trim() : '';

  void _import() {
    if (_preview == null || _preview!.isEmpty) return;
    setState(() => _isImporting = true);
    context.read<ClientsBloc>().add(BulkImportClients(_preview!));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientsBloc, ClientsState>(
      listener: (context, state) {
        if (_isImporting) {
          if (state is ClientsLoaded) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_preview?.length ?? 0} clients imported successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is ClientsError) {
            setState(() => _isImporting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        }
      },
      builder: (context, state) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 560),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bulk Import Clients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload a CSV with columns: name, mobile, venue (required), company, email, remark (optional)',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _downloadSample,
                  child: const Text(
                    'Download sample CSV',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose CSV File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_preview!.length} clients ready to import:',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _preview!.length > 5 ? 5 : _preview!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = _preview![i];
                          return ListTile(
                            dense: true,
                            title: Text(c.name, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(c.mobileNumber, style: const TextStyle(fontSize: 12)),
                            trailing: c.companyName != null
                                ? Text(c.companyName!, style: const TextStyle(fontSize: 12, color: Colors.grey))
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                  if (_preview!.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '... and ${_preview!.length - 5} more',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_preview != null && !_isImporting) ? _import : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isImporting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Import Clients'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
