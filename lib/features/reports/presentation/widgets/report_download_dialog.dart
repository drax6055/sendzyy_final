import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/core/widgets/compact_date_range_picker.dart';
import 'package:sendzyy/features/reports/presentation/utils/pdf_utils.dart'
    as pdf;

class ReportDownloadDialog extends StatefulWidget {
  final List<Map<String, dynamic>> campaigns;

  const ReportDownloadDialog({super.key, required this.campaigns});

  @override
  State<ReportDownloadDialog> createState() => _ReportDownloadDialogState();
}

class _ReportDownloadDialogState extends State<ReportDownloadDialog> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Download Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select date range for the campaign report:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildDateRangeTile(
              label: 'Date Range',
              range: _dateRange,
              onTap: () async {
                final range = await showCompactDateRangePicker(
                  context: context,
                  initialDateRange: _dateRange,
                  firstDate: DateTime(2025),
                  lastDate: DateTime.now(),
                );
                if (range != null) setState(() => _dateRange = range);
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _dateRange == null
                    ? null
                    : () {
                        pdf.PdfUtils.generateCampaignReport(
                          campaigns: widget.campaigns,
                          dateRange: _dateRange!,
                        );
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Download PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeTile({
    required String label,
    required DateTimeRange? range,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  range != null
                      ? '${DateFormat('MMM dd').format(range.start)} - ${DateFormat('MMM dd, yyyy').format(range.end)}'
                      : 'Select Date Range',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

