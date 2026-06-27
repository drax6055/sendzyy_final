import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/retry_repository.dart';
import 'package:iFloraBuzz/features/reports/presentation/utils/pdf_utils.dart';
import 'package:intl/intl.dart';

class PhaseReportDialog extends StatefulWidget {
  final String campaignId;
  final String campaignTemplate;

  const PhaseReportDialog({
    super.key,
    required this.campaignId,
    required this.campaignTemplate,
  });

  @override
  State<PhaseReportDialog> createState() => _PhaseReportDialogState();
}

class _PhaseReportDialogState extends State<PhaseReportDialog> {
  late Future<Map<String, dynamic>?> _reportFuture;
  Map<String, dynamic>? _currentReport;

  @override
  void initState() {
    super.initState();
    _reportFuture = getIt<RetryRepository>().getCampaignReport(widget.campaignId);
  }

  void _reload() {
    setState(() {
      _reportFuture = getIt<RetryRepository>().getCampaignReport(widget.campaignId);
    });
  }

  Future<void> _downloadPdf() async {
    if (_currentReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for report to load')),
      );
      return;
    }

    try {
      await PdfUtils.generatePhaseReport(
        campaignTemplate: widget.campaignTemplate,
        report: _currentReport!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 8),
                          const Text('Failed to load report'),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _reload, child: const Text('Retry')),
                        ],
                      ),
                    );
                  }
                  // Store the report data for PDF generation
                  _currentReport = snapshot.data;
                  return _buildReport(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: AppTheme.secondaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phase Report - ${widget.campaignTemplate}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                ),
                const Text('Delivery breakdown by retry phase', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reload),
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 20),
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildReport(Map<String, dynamic> report) {
    final totalRecipients = (report['totalRecipients'] as num?)?.toInt() ?? 0;
    final cumulativeSuccess = (report['cumulativeSuccess'] as num?)?.toInt() ?? 0;
    final overallRate = (report['overallSuccessRate'] as num?)?.toDouble() ?? 0.0;
    final campaignStatus = report['status'] as String? ?? 'initial';
    final phases = List<Map<String, dynamic>>.from(report['phases'] ?? []);

    // If status is still 'initial' but there are pending retry phases, treat as 'retrying'
    final hasPendingPhase = phases.any((p) {
      final s = p['status'] as String? ?? '';
      return s == 'pending' || s == 'scheduled';
    });
    final displayStatus = (campaignStatus == 'initial' && hasPendingPhase) ? 'retrying' : campaignStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _summaryCard('Total', '$totalRecipients', Icons.people_outline, Colors.blue),
              const SizedBox(width: 12),
              _summaryCard('Delivered', '$cumulativeSuccess', Icons.done_all, Colors.green),
              const SizedBox(width: 12),
              _summaryCard('Success Rate', '${overallRate.toStringAsFixed(1)}%', Icons.percent, _rateColor(overallRate)),
              const SizedBox(width: 12),
              _summaryCard('Status', _statusLabel(displayStatus), _statusIcon(displayStatus), _statusColor(displayStatus)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Phase Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          if (phases.isEmpty)
            const Text('No phase data available.', style: TextStyle(color: Colors.grey))
          else
            ...phases.map((p) => _buildPhaseCard(p)),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseCard(Map<String, dynamic> phase) {
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
    final color = isPending ? Colors.orange : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPending ? Colors.orange.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('$phaseNum', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phaseLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (intervalHours != null && phaseNum > 1)
                      Text('Interval: ${intervalHours}h after previous phase', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              _phaseBadge(status),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            if (scheduledAt != null)
              Row(children: [
                const Icon(Icons.schedule, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text('Scheduled: ${_fmtDateTime(scheduledAt)}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
              ]),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _statPill('Sent', successCount + failureCount, Colors.blue),
                const SizedBox(width: 8),
                _statPill('Delivered', successCount, Colors.green),
                const SizedBox(width: 8),
                _statPill('Failed', failureCount, Colors.red),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${successRate.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _rateColor(successRate))),
                    const Text('success rate', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: successRate / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(_rateColor(successRate)),
              ),
            ),
            if (executedAt != null) ...[
              const SizedBox(height: 6),
              Text('Executed: ${_fmtDateTime(executedAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _phaseBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
      case 'scheduled':
        color = Colors.orange; label = 'Scheduled'; break;
      case 'completed':
        color = Colors.green; label = 'Completed'; break;
      case 'executing':
        color = Colors.blue; label = 'Running'; break;
      default:
        color = Colors.grey; label = status[0].toUpperCase() + status.substring(1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _statPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  String _fmtDateTime(String iso) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }

  Color _rateColor(double rate) {
    if (rate >= 70) return Colors.green;
    if (rate >= 40) return Colors.orange;
    return Colors.red;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'initial': return 'Sending';
      case 'retrying': return 'Retrying';
      case 'completed': return 'Done';
      case 'error': return 'Error';
      default: return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'retrying': return Icons.replay_outlined;
      case 'completed': return Icons.check_circle_outline;
      case 'error': return Icons.error_outline;
      default: return Icons.send_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'retrying': return Colors.orange;
      case 'completed': return Colors.green;
      case 'error': return Colors.red;
      default: return Colors.blue;
    }
  }
}
