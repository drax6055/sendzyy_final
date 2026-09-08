import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

/// Dialog to batch import products from a CSV file
class BatchImportDialog extends StatefulWidget {
  final String catalogId;

  const BatchImportDialog({super.key, required this.catalogId});

  static Future<void> show(BuildContext context, String catalogId) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CatalogBloc>(),
        child: BatchImportDialog(catalogId: catalogId),
      ),
    );
  }

  @override
  State<BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<BatchImportDialog> {
  List<Map<String, dynamic>> _parsedProducts = [];
  String? _fileName;
  String? _error;
  bool _isLoading = false;

  static const _csvTemplate = 'retailerId,name,description,price,currency,imageUrl,availability,condition,brand,category\n'
      'SKU001,Sample Product,A great product,499,INR,https://example.com/img.jpg,in stock,new,MyBrand,Electronics';

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogOperationSuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        }
        if (state is CatalogError) {
          setState(() => _isLoading = false);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Batch Import Products',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: const Color(0xFF1A1A2E))),
                          Text('Upload a CSV file with product data',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),

                // CSV template download
                InkWell(
                  onTap: _downloadTemplate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Download CSV template',
                              style: GoogleFonts.inter(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.blue.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Upload area
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _parsedProducts.isNotEmpty ? Colors.green.shade400 : const Color(0xFFD1D5DB),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _parsedProducts.isNotEmpty ? Colors.green.shade50 : const Color(0xFFF9FAFB),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _parsedProducts.isNotEmpty ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                          size: 40,
                          color: _parsedProducts.isNotEmpty ? Colors.green.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _fileName ?? 'Click to select CSV file',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: _fileName != null ? const Color(0xFF1A1A2E) : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_parsedProducts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_parsedProducts.length} products ready to import',
                            style: GoogleFonts.inter(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12)),
                  ),
                ],

                // Preview table
                if (_parsedProducts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Preview (first 3 rows)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Currency')),
                        ],
                        rows: _parsedProducts.take(3).map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p['retailerId']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(p['price']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(p['currency']?.toString() ?? 'INR', style: const TextStyle(fontSize: 12))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Import button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_parsedProducts.isEmpty || _isLoading) ? null : _import,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Importing...' : 'Import ${_parsedProducts.length} Products',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final content = String.fromCharCodes(bytes);
      _parseCSV(content, file.name);
    } catch (e) {
      setState(() => _error = 'Error reading file: $e');
    }
  }

  void _parseCSV(String content, String fileName) {
    try {
      final rows = const CsvToListConverter().convert(content, eol: '\n');
      if (rows.isEmpty) {
        setState(() => _error = 'CSV file is empty');
        return;
      }

      final headers = rows.first.map((h) => h.toString().trim()).toList();
      final required = ['retailerId', 'name', 'price', 'imageUrl'];
      final missing = required.where((r) => !headers.contains(r)).toList();
      if (missing.isNotEmpty) {
        setState(() => _error = 'Missing required columns: ${missing.join(', ')}');
        return;
      }

      final products = <Map<String, dynamic>>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) continue;

        final product = <String, dynamic>{};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          product[headers[j]] = row[j].toString().trim();
        }
        if (product['retailerId']?.isNotEmpty == true && product['name']?.isNotEmpty == true) {
          products.add(product);
        }
      }

      setState(() {
        _parsedProducts = products;
        _fileName = fileName;
        _error = products.isEmpty ? 'No valid products found in CSV' : null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to parse CSV: $e');
    }
  }

  void _downloadTemplate() {
    // Copy template to clipboard as fallback
    Clipboard.setData(ClipboardData(text: _csvTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV template copied to clipboard!'), backgroundColor: Colors.blue),
    );
  }

  void _import() {
    setState(() => _isLoading = true);
    context.read<CatalogBloc>().add(BatchImportProducts(
      catalogId: widget.catalogId,
      products: _parsedProducts,
    ));
  }
}
