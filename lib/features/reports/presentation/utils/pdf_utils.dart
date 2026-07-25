import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart';

class PdfUtils {
  static Future<void> generateCampaignReport({
    required List<Map<String, dynamic>> campaigns,
    required DateTimeRange dateRange,
  }) async {
    final pdf = pw.Document();

    final filteredCampaigns = campaigns.where((c) {
      final timestamp = c['timestamp'];
      final DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp).toLocal();
      } else if (timestamp is int) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
      } else {
        date = DateTime.now();
      }
      return date.isAfter(dateRange.start) &&
          date.isBefore(dateRange.end.add(const Duration(days: 1)));
    }).toList();

    // Calculate Totals
    int totalSent = 0;
    int totalDelivered = 0;
    int totalRead = 0;
    int totalFailed = 0;

    for (var c in filteredCampaigns) {
      totalSent += (c['successCount'] as num? ?? 0).toInt();
      totalDelivered += (c['deliveredCount'] as num? ?? 0).toInt();
      totalRead += (c['readCount'] as num? ?? 0).toInt();
      totalFailed += (c['failureCount'] as num? ?? 0).toInt();
    }

    const primaryGreen = PdfColor.fromInt(0xFF25D366);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Sendzyy',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  pw.Text(
                    'WhatsApp Campaign Report',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Report Period',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    '${DateFormat('MMM dd').format(dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange.end)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: primaryGreen, thickness: 2),
          pw.SizedBox(height: 24),

          // Summary Section
          pw.Text(
            'Campaign Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total Sent', totalSent.toString(), PdfColors.blue700),
              _buildStatCard('Delivered', totalDelivered.toString(), PdfColors.green700),
              _buildStatCard('Read', totalRead.toString(), PdfColors.orange700),
              _buildStatCard('Failed', totalFailed.toString(), PdfColors.red700),
            ],
          ),
          pw.SizedBox(height: 32),

          // Details Table
          pw.Text(
            'Detailed Report',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Template', 'Sent', 'Delivered', 'Read', 'Failed'],
            data: List<List<dynamic>>.generate(filteredCampaigns.length, (index) {
              final c = filteredCampaigns[index];
              final timestamp = c['timestamp'];
              final dateStr = timestamp is String
                  ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(timestamp).toLocal())
                  : timestamp is int
                      ? DateFormat('MMM dd, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal())
                      : 'N/A';

              return [
                dateStr,
                c['template'] ?? 'N/A',
                c['totalCount'] ?? 0,
                c['deliveredCount'] ?? 0,
                c['readCount'] ?? 0,
                c['failureCount'] ?? 0,
              ];
            }),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: primaryGreen),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),

          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Confidential - Generated for Internal Use.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Text(
                'Report Generated on: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'campaign_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> generateCampaignDetailReport({
    required Map<String, dynamic> campaign,
    required List<Map<String, dynamic>> recipients,
  }) async {
    final pdf = pw.Document();
    const primaryGreen = PdfColor.fromInt(0xFF25D366);

    final template = campaign['template'] ?? 'N/A';
    final timestamp = campaign['timestamp'];
    final dateStr = timestamp is String
        ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(timestamp).toLocal())
        : 'N/A';

    int sent = 0, delivered = 0, read = 0, failed = 0;
    for (final r in recipients) {
      final s = r['status'] as String? ?? 'sent';
      if (s == 'delivered') delivered++;
      else if (s == 'read') read++;
      else if (s == 'failed') failed++;
      else sent++;
    } 

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Sendzyy',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primaryGreen)),
                  pw.Text('Campaign Detail Report',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text(DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: primaryGreen, thickness: 2),
          pw.SizedBox(height: 16),

          pw.Text('Campaign: $template',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Sent on: $dateStr',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 20),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Sent', sent.toString(), PdfColors.blue700),
              _buildStatCard('Delivered', delivered.toString(), PdfColors.green700),
              _buildStatCard('Read', read.toString(), PdfColors.orange700),
              _buildStatCard('Failed', failed.toString(), PdfColors.red700),
            ],
          ),
          pw.SizedBox(height: 28),

          pw.Text('Recipient Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Phone Number', 'Status', 'Sent At', 'Delivered At', 'Read At', 'Failed At'],
            data: recipients.map((r) {
              String fmt(String? iso) {
                if (iso == null) return '-';
                try {
                  final dt = DateTime.parse(iso).toLocal();
                  return DateFormat('HH:mm').format(dt);
                } catch (_) {
                  return iso;
                }
              }

              final status = r['status'] as String? ?? 'sent';
              return [
                r['to'] ?? '-',
                status[0].toUpperCase() + status.substring(1),
                fmt(r['sentAt'] as String?),
                fmt(r['deliveredAt'] as String?),
                fmt(r['readAt'] as String?),
                fmt(r['failedAt'] as String?),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: primaryGreen),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),

          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Confidential - Generated for Internal Use.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Report Generated on: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'campaign_${template}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> generateCampaignDetailExcel({
    required Map<String, dynamic> campaign,
    required List<Map<String, dynamic>> recipients,
  }) async {
    final template = campaign['template'] ?? 'N/A';
    final timestamp = campaign['timestamp'];
    final dateStr = timestamp is String
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(timestamp).toLocal())
        : 'N/A';

    int sent = 0, delivered = 0, read = 0, failed = 0;
    for (final r in recipients) {
      final s = r['status'] as String? ?? 'sent';
      if (s == 'delivered') delivered++;
      else if (s == 'read') read++;
      else if (s == 'failed') failed++;
      else sent++;
    } 

    final List<List<dynamic>> rows = [];
    
    // Header information
    rows.add(['Campaign Detail Report']);
    rows.add(['Campaign Name', template]);
    rows.add(['Sent Date', dateStr]);
    rows.add([]); // Blank line
    
    // Summary table
    rows.add(['Summary']);
    rows.add(['Status', 'Count']);
    rows.add(['Sent', sent]);
    rows.add(['Delivered', delivered]);
    rows.add(['Read', read]);
    rows.add(['Failed', failed]);
    rows.add([]); // Blank line

    // Details header
    rows.add(['Recipient Details']);
    rows.add(['Phone Number', 'Status', 'Sent At', 'Delivered At', 'Read At', 'Failed At']);
    
    String fmt(String? iso) {
      if (iso == null) return '-';
      try {
        final dt = DateTime.parse(iso).toLocal();
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      } catch (_) {
        return iso;
      }
    }

    // Add recipient details rows
    for (final r in recipients) {
      final status = r['status'] as String? ?? 'sent';
      rows.add([
        r['to'] ?? '-',
        status[0].toUpperCase() + status.substring(1),
        fmt(r['sentAt'] as String?),
        fmt(r['deliveredAt'] as String?),
        fmt(r['readAt'] as String?),
        fmt(r['failedAt'] as String?),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);
    final fileName = 'campaign_${template}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      } catch (e) {
        debugPrint("Error writing CSV: $e");
      }
    }
  }

  static Future<void> generatePhaseReport({
    required String campaignTemplate,
    required Map<String, dynamic> report,
  }) async {
    final pdf = pw.Document();
    const primaryGreen = PdfColor.fromInt(0xFF25D366);

    final totalRecipients = (report['totalRecipients'] as num?)?.toInt() ?? 0;
    final cumulativeSuccess = (report['cumulativeSuccess'] as num?)?.toInt() ?? 0;
    final overallRate = (report['overallSuccessRate'] as num?)?.toDouble() ?? 0.0;
    final campaignStatus = report['status'] as String? ?? 'initial';
    final phases = List<Map<String, dynamic>>.from(report['phases'] ?? []);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Sendzyy',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primaryGreen)),
                  pw.Text('Phase Report - $campaignTemplate',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Delivery breakdown by retry phase',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text(DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: primaryGreen, thickness: 2),
          pw.SizedBox(height: 20),

          // Summary Cards
          pw.Text('Campaign Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total', totalRecipients.toString(), PdfColors.blue700),
              _buildStatCard('Delivered', cumulativeSuccess.toString(), PdfColors.green700),
              _buildStatCard('Success Rate', '${overallRate.toStringAsFixed(1)}%', 
                  overallRate >= 70 ? PdfColors.green700 : overallRate >= 40 ? PdfColors.orange700 : PdfColors.red700),
              _buildStatCard('Status', _statusLabel(campaignStatus), _statusColor(campaignStatus)),
            ],
          ),
          pw.SizedBox(height: 28),

          // Phase Breakdown
          pw.Text('Phase Breakdown',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          ...phases.map((phase) => _buildPhaseSection(phase)),

          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Confidential - Generated for Internal Use.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Report Generated on: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'phase_report_${campaignTemplate}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> generatePhaseReportExcel({
    required String campaignTemplate,
    required Map<String, dynamic> report,
  }) async {
    final totalRecipients = (report['totalRecipients'] as num?)?.toInt() ?? 0;
    final cumulativeSuccess = (report['cumulativeSuccess'] as num?)?.toInt() ?? 0;
    final overallRate = (report['overallSuccessRate'] as num?)?.toDouble() ?? 0.0;
    final campaignStatus = report['status'] as String? ?? 'initial';
    final phases = List<Map<String, dynamic>>.from(report['phases'] ?? []);

    final List<List<dynamic>> rows = [];
    rows.add(['Phase Report - $campaignTemplate']);
    rows.add(['Delivery breakdown by retry phase']);
    rows.add([]); // Blank line

    rows.add(['Summary']);
    rows.add(['Metric', 'Value']);
    rows.add(['Total', totalRecipients]);
    rows.add(['Delivered', cumulativeSuccess]);
    rows.add(['Success Rate', '${overallRate.toStringAsFixed(1)}%']);
    rows.add(['Status', campaignStatus[0].toUpperCase() + campaignStatus.substring(1)]);
    rows.add([]); // Blank line

    rows.add(['Phase Breakdown']);
    rows.add(['Phase', 'Status', 'Sent', 'Delivered', 'Failed', 'Success Rate', 'Executed At']);

    for (final phase in phases) {
      final phaseNum = (phase['phaseNumber'] as num?)?.toInt() ?? 0;
      final status = phase['status'] as String? ?? 'completed';
      final successCount = (phase['successCount'] as num?)?.toInt() ?? 0;
      final failureCount = (phase['failureCount'] as num?)?.toInt() ?? 0;
      final successRate = (phase['successRate'] as num?)?.toDouble() ?? 0.0;
      final executedAt = phase['executedAt'] as String?;

      String fmt(String? iso) {
        if (iso == null) return '-';
        try {
          final dt = DateTime.parse(iso).toLocal();
          return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
        } catch (_) {
          return iso;
        }
      }

      rows.add([
        phaseNum == 1 ? 'Initial Send' : 'Retry Phase $phaseNum',
        status[0].toUpperCase() + status.substring(1),
        successCount,
        successCount,
        failureCount,
        '${successRate.toStringAsFixed(1)}%',
        fmt(executedAt),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);
    final fileName = 'phase_report_${campaignTemplate}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      } catch (e) {
        debugPrint("Error writing CSV: $e");
      }
    }
  }

  static pw.Widget _buildPhaseSection(Map<String, dynamic> phase) {
    final phaseNum = (phase['phaseNumber'] as num?)?.toInt() ?? 0;
    final status = phase['status'] as String? ?? 'completed';
    final isPending = status == 'pending' || status == 'scheduled';
    final successCount = (phase['successCount'] as num?)?.toInt() ?? 0;
    final failureCount = (phase['failureCount'] as num?)?.toInt() ?? 0;
    final successRate = (phase['successRate'] as num?)?.toDouble() ?? 0.0;
    final intervalHours = (phase['intervalHours'] as num?)?.toInt();
    final scheduledAt = phase['scheduledAt'] as String?;
    final executedAt = phase['executedAt'] as String?;
    final phaseLabel = phaseNum == 1 ? 'Initial Send' : 'Retry Phase $phaseNum';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 28,
                    height: 28,
                    decoration: pw.BoxDecoration(
                      color: isPending ? PdfColors.orange100 : PdfColors.green100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('$phaseNum',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: isPending ? PdfColors.orange700 : PdfColors.green700,
                            fontSize: 12)),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(phaseLabel,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      if (intervalHours != null && phaseNum > 1)
                        pw.Text('Interval: ${intervalHours}h after previous phase',
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: isPending ? PdfColors.orange100 : PdfColors.green100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  isPending ? 'Scheduled' : 'Completed',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: isPending ? PdfColors.orange700 : PdfColors.green700),
                ),
              ),
            ],
          ),
          if (isPending) ...[
            pw.SizedBox(height: 8),
            if (scheduledAt != null)
              pw.Text('Scheduled: ${_fmtDateTime(scheduledAt)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.orange700)),
          ] else ...[
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sent: ${successCount + failureCount}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.blue700)),
                pw.Text('Delivered: $successCount',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                pw.Text('Failed: $failureCount',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.red700)),
                pw.Text('${successRate.toStringAsFixed(1)}% success',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: successRate >= 70
                            ? PdfColors.green700
                            : successRate >= 40
                                ? PdfColors.orange700
                                : PdfColors.red700)),
              ],
            ),
            if (executedAt != null) ...[
              pw.SizedBox(height: 6),
              pw.Text('Executed: ${_fmtDateTime(executedAt)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ],
        ],
      ),
    );
  }

  static String _fmtDateTime(String iso) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'initial':
        return 'Sending';
      case 'retrying':
        return 'Retrying';
      case 'completed':
        return 'Done';
      case 'error':
        return 'Error';
      default:
        return status;
    }
  }

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'retrying':
        return PdfColors.orange700;
      case 'completed':
        return PdfColors.green700;
      case 'error':
        return PdfColors.red700;
      default:
        return PdfColors.blue700;
    }
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
