import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/retry_repository.dart';
import 'package:iFloraBuzz/features/reports/presentation/utils/pdf_utils.dart';
import 'package:intl/intl.dart';

class CampaignReportDialog extends StatefulWidget {
  final Map<String, dynamic> campaign;

  const CampaignReportDialog({super.key, required this.campaign});

  @override
  State<CampaignReportDialog> createState() => _CampaignReportDialogState();
}

class _CampaignReportDialogState extends State<CampaignReportDialog>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _recipientsFuture;
  late Future<Map<String, dynamic>?> _phaseReportFuture;

  Map<String, dynamic>? _currentPhaseReport;

  String _recipientFilter = 'all';
  bool _isDownloadingCampaignReport = false;
  bool _isDownloadingPhaseReport = false;

  TabController? _tabController;
  int _activeTabIndex = 0;
  bool _hasPhases = false;

  @override
  void initState() {
    super.initState();
    final campaignId = widget.campaign['id'] as String? ?? '';
    _recipientsFuture =
        getIt<WhatsAppRepository>().getCampaignRecipients(campaignId);

    _hasPhases = _hasRetryPhases(widget.campaign);
    if (_hasPhases) {
      _phaseReportFuture =
          getIt<RetryRepository>().getCampaignReport(campaignId);
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _activeTabIndex = _tabController!.index;
          });
        }
      });
    } else {
      _phaseReportFuture = Future.value(null);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool _hasRetryPhases(Map<String, dynamic> campaign) {
    final phases = campaign['retryConfig']?['phases'] as List?;
    return phases != null && phases.isNotEmpty;
  }

  void _reloadPhaseReport() {
    final campaignId = widget.campaign['id'] as String? ?? '';
    setState(() {
      _phaseReportFuture =
          getIt<RetryRepository>().getCampaignReport(campaignId);
    });
  }

  Future<void> _downloadPhasePdf() async {
    if (_currentPhaseReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for report to load')),
      );
      return;
    }

    setState(() => _isDownloadingPhaseReport = true);
    try {
      await PdfUtils.generatePhaseReport(
        campaignTemplate: widget.campaign['template'] as String? ?? '-',
        report: _currentPhaseReport!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPhaseReport = false);
    }
  }

  Future<void> _downloadPhaseExcel() async {
    if (_currentPhaseReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for report to load')),
      );
      return;
    }

    setState(() => _isDownloadingPhaseReport = true);
    try {
      await PdfUtils.generatePhaseReportExcel(
        campaignTemplate: widget.campaign['template'] as String? ?? '-',
        report: _currentPhaseReport!,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPhaseReport = false);
    }
  }

  Color _recipientStatusColor(String status) {
    switch (status) {
      case 'read':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _recipientStatusIcon(String status) {
    switch (status) {
      case 'read':
        return Icons.remove_red_eye;
      case 'delivered':
        return Icons.done_all;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.send;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_hasPhases && _tabController != null)
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Phase Report'),
                  Tab(text: 'Campaign Report'),
                ],
              ),
            const Divider(height: 1),
            Expanded(
              child: _hasPhases && _tabController != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPhaseReportTab(),
                        _buildCampaignReportTab(),
                      ],
                    )
                  : _buildCampaignReportTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final c = widget.campaign;
    final showPhaseControls = _hasPhases && _activeTabIndex == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            showPhaseControls
                ? Icons.analytics_outlined
                : Icons.campaign_outlined,
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showPhaseControls
                      ? 'Phase Report - ${c['template'] ?? '-'}'
                      : 'Campaign: ${c['template'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Text(
                  showPhaseControls
                      ? 'Delivery breakdown by retry phase'
                      : c['timestamp'] != null
                          ? () {
                              final raw = c['timestamp'].toString();
                              final dt = DateTime.tryParse(raw)?.toLocal();
                              return dt != null
                                  ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                  : raw.substring(
                                      0,
                                      raw.length >= 16 ? 16 : raw.length,
                                    );
                            }()
                          : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (showPhaseControls) ...[
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _reloadPhaseReport,
              tooltip: 'Reload Phase Report',
            ),
            _isDownloadingPhaseReport
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.download_outlined, size: 20),
                    tooltip: 'Export Options',
                    onSelected: (value) async {
                      if (value == 'pdf') {
                        _downloadPhasePdf();
                      } else if (value == 'excel') {
                        _downloadPhaseExcel();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Download PDF'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'excel',
                        child: Row(
                          children: [
                            Icon(Icons.table_view, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Download Excel (CSV)'),
                          ],
                        ),
                      ),
                    ],
                  ),
          ] else ...[
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _recipientsFuture,
              builder: (context, snapshot) {
                final recipients = snapshot.data ?? [];
                final isLoaded = snapshot.connectionState == ConnectionState.done;
                return _isDownloadingCampaignReport
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.download_outlined, size: 20),
                        tooltip: 'Export Options',
                        onSelected: isLoaded
                            ? (value) async {
                                if (value == 'pdf') {
                                  setState(() => _isDownloadingCampaignReport = true);
                                  try {
                                    await PdfUtils.generateCampaignDetailReport(
                                      campaign: widget.campaign,
                                      recipients: recipients,
                                    );
                                  } finally {
                                    if (mounted) setState(() => _isDownloadingCampaignReport = false);
                                  }
                                } else if (value == 'excel') {
                                  setState(() => _isDownloadingCampaignReport = true);
                                  try {
                                    await PdfUtils.generateCampaignDetailExcel(
                                      campaign: widget.campaign,
                                      recipients: recipients,
                                    );
                                  } finally {
                                    if (mounted) setState(() => _isDownloadingCampaignReport = false);
                                  }
                                }
                              }
                            : null,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Download PDF'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'excel',
                            child: Row(
                              children: [
                                Icon(Icons.table_view, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Text('Download Excel (CSV)'),
                              ],
                            ),
                          ),
                        ],
                      );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseReportTab() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _phaseReportFuture,
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
                TextButton(
                  onPressed: _reloadPhaseReport,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        _currentPhaseReport = snapshot.data;
        return _buildPhaseReportContent(snapshot.data!);
      },
    );
  }

  Widget _buildPhaseReportContent(Map<String, dynamic> report) {
    final totalRecipients = (report['totalRecipients'] as num?)?.toInt() ?? 0;
    final cumulativeSuccess =
        (report['cumulativeSuccess'] as num?)?.toInt() ?? 0;
    final overallRate =
        (report['overallSuccessRate'] as num?)?.toDouble() ?? 0.0;
    final campaignStatus = report['status'] as String? ?? 'initial';
    final phases = List<Map<String, dynamic>>.from(report['phases'] ?? []);

    final hasPendingPhase = phases.any((p) {
      final s = p['status'] as String? ?? '';
      return s == 'pending' || s == 'scheduled';
    });
    final displayStatus =
        (campaignStatus == 'initial' && hasPendingPhase)
            ? 'retrying'
            : campaignStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _summaryCard(
                'Total',
                '$totalRecipients',
                Icons.people_outline,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Delivered',
                '$cumulativeSuccess',
                Icons.done_all,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Success Rate',
                '${overallRate.toStringAsFixed(1)}%',
                Icons.percent,
                _rateColor(overallRate),
              ),
              const SizedBox(width: 12),
              _summaryCard(
                'Status',
                _campaignStatusLabel(displayStatus),
                _campaignStatusIcon(displayStatus),
                _campaignStatusColor(displayStatus),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Phase Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (phases.isEmpty)
            const Text(
              'No phase data available.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...phases.map((p) => _buildPhaseCard(p)),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
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
        border: Border.all(
          color:
              isPending
                  ? Colors.orange.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$phaseNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phaseLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (intervalHours != null && phaseNum > 1)
                      Text(
                        'Interval: ${intervalHours}h after previous phase',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              _phaseBadge(status),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            if (scheduledAt != null)
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    'Scheduled: ${_fmtDateTime(scheduledAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statPill('Sent', successCount + failureCount, Colors.blue),
                    _statPill('Delivered', successCount, Colors.green),
                    _statPill('Failed', failureCount, Colors.red),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${successRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _rateColor(successRate),
                      ),
                    ),
                    const Text(
                      'success rate',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  _rateColor(successRate),
                ),
              ),
            ),
            if (executedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Executed: ${_fmtDateTime(executedAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
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
        color = Colors.orange;
        label = 'Scheduled';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      case 'executing':
        color = Colors.blue;
        label = 'Running';
        break;
      default:
        color = Colors.grey;
        label = status[0].toUpperCase() + status.substring(1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _statPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  String _fmtDateTime(String iso) {
    try {
      return DateFormat(
        'dd MMM yyyy, HH:mm',
      ).format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Color _rateColor(double rate) {
    if (rate >= 70) return Colors.green;
    if (rate >= 40) return Colors.orange;
    return Colors.red;
  }

  String _campaignStatusLabel(String status) {
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

  IconData _campaignStatusIcon(String status) {
    switch (status) {
      case 'retrying':
        return Icons.replay_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.send_outlined;
    }
  }

  Color _campaignStatusColor(String status) {
    switch (status) {
      case 'retrying':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildCampaignReportTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recipientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final all = snapshot.data ?? [];

        // Compute counts directly from the recipients list so chips
        // always match the actual rows displayed below.
        // Fall back to campaign-doc totals only when recipient data is absent.
        final int sentCount;
        final int deliveredCount;
        final int readCount;
        final int failedCount;

        if (all.isEmpty) {
          // No recipient documents yet — fall back to campaign-level fields
          sentCount     = (widget.campaign['totalCount'] as num? ?? 0).toInt();
          deliveredCount = ((widget.campaign['deliveredCount'] as num? ?? 0).toInt()).clamp(0, 9999999);
          readCount     = (widget.campaign['readCount'] as num? ?? 0).toInt();
          failedCount   = (widget.campaign['failureCount'] as num? ?? 0).toInt();
        } else {
          // Count directly from the loaded recipient documents
          sentCount     = all.length;
          deliveredCount = all.where((r) {
            final s = r['status'] as String? ?? '';
            return s == 'delivered' || s == 'read';
          }).length;
          readCount     = all.where((r) => (r['status'] as String? ?? '') == 'read').length;
          failedCount   = all.where((r) => (r['status'] as String? ?? '') == 'failed').length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip('Sent', sentCount, Colors.blue),
                  _statChip('Delivered', deliveredCount, Colors.green),
                  _statChip('Read', readCount, Colors.orange),
                  _statChip('Failed', failedCount, Colors.red),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['all', 'sent', 'delivered', 'read', 'failed']
                          .map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label:
                                    Text(f[0].toUpperCase() + f.substring(1)),
                                selected: _recipientFilter == f,
                                onSelected:
                                    (_) => setState(() => _recipientFilter = f),
                                selectedColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(child: _buildRecipientsList(all)),
          ],
        );
      },
    );
  }

  Widget _buildRecipientsList(List<Map<String, dynamic>> all) {
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No recipient data yet.\nNew campaigns will show details here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final filtered =
        _recipientFilter == 'all'
            ? all
            : all
                .where((r) => (r['status'] ?? 'sent') == _recipientFilter)
                .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No recipients with status "$_recipientFilter"',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 24),
      itemBuilder: (context, i) {
        final r = filtered[i];
        final status = r['status'] as String? ?? 'sent';
        final to = r['to'] as String? ?? '-';
        final sentAt = r['sentAt'] as String?;
        final deliveredAt = r['deliveredAt'] as String?;
        final readAt = r['readAt'] as String?;
        final failedAt = r['failedAt'] as String?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: _recipientStatusColor(status).withValues(
              alpha: 0.1,
            ),
            child: Icon(
              _recipientStatusIcon(status),
              size: 16,
              color: _recipientStatusColor(status),
            ),
          ),
          title: Text(
            to,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: _buildTimeline(sentAt, deliveredAt, readAt, failedAt),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _recipientStatusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _recipientStatusColor(status),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    String? sentAt,
    String? deliveredAt,
    String? readAt,
    String? failedAt,
  ) {
    final parts = <String>[];
    if (sentAt != null) parts.add('Sent ${_fmt(sentAt)}');
    if (deliveredAt != null) parts.add('Delivered ${_fmt(deliveredAt)}');
    if (readAt != null) parts.add('Read ${_fmt(readAt)}');
    if (failedAt != null) parts.add('Failed ${_fmt(failedAt)}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 11, color: Colors.grey, overflow: TextOverflow.ellipsis),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
