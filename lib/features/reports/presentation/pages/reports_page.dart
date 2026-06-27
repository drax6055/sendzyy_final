import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/reports/presentation/bloc/report_bloc.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/campaign_detail_dialog.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/phase_report_dialog.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/report_download_dialog.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange? _dateRange;
  String _templateFilter = 'all';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ReportBloc, ReportState>(
        builder: (ctx, state) {
          if (state is ReportLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ReportError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is ReportLoaded) {
            // Derive unique template names for the dropdown
            final templateOptions = state.campaigns
                .map((c) => c['template'] as String? ?? '')
                .where((t) => t.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            // Filter campaigns client-side
            final filtered = state.campaigns.where((c) {
              // Template filter
              if (_templateFilter != 'all') {
                final t = c['template'] as String? ?? '';
                if (t != _templateFilter) return false;
              }
              // Date range filter
              if (_dateRange != null) {
                final dynamic ts = c['timestamp'];
                final DateTime date;
                if (ts is String) {
                  date = (DateTime.tryParse(ts) ?? DateTime.now()).toLocal();
                } else if (ts is int) {
                  date = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();
                } else {
                  date = DateTime.now();
                }
                final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
                final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
                if (date.isBefore(start) || date.isAfter(end)) return false;
              }
              return true;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async {
                ctx.read<ReportBloc>().add(FetchReportHistory());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Campaign Reports',
                            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ),
                          ),
                        ),
                        // Template filter dropdown
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            value: templateOptions.contains(_templateFilter) ? _templateFilter : 'all',
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All Templates')),
                              ...templateOptions.map(
                                (t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                              ),
                            ],
                            onChanged: (v) => setState(() => _templateFilter = v ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Date range filter button
                        _DateRangeButton(
                          dateRange: _dateRange,
                          onChanged: (r) => setState(() => _dateRange = r),
                          onClear: () => setState(() => _dateRange = null),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (_) => ReportDownloadDialog(
                                campaigns: filtered,
                              ),
                            );
                          },
                          tooltip: 'Download Report',
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () =>
                              ctx.read<ReportBloc>().add(FetchReportHistory()),
                          tooltip: 'Reload History',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildStatGrid(state, filtered),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Text(
                          'Recent Campaigns',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_dateRange != null || _templateFilter != 'all') ...[
                          const SizedBox(width: 10),
                          Text(
                            '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCampaignTable(ctx, state, filtered),
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text('No reports available yet.'));
        },
      ),
    );
  }

  Widget _buildStatGrid(ReportLoaded state, List<Map<String, dynamic>> campaigns) {
    // Compute stats from filtered campaigns
    int sent = 0, delivered = 0, read = 0, failed = 0;
    for (final c in campaigns) {
      sent += (c['successCount'] as num? ?? 0).toInt();
      delivered += (c['deliveredCount'] as num? ?? 0).toInt();
      read += (c['readCount'] as num? ?? 0).toInt();
      failed += (c['failureCount'] as num? ?? 0).toInt();
    }
    return Row(
      children: [
        _buildStatCard('Total Sent', '$sent', Icons.send, Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard('Delivered', '$delivered', Icons.done_all, Colors.green),
        const SizedBox(width: 16),
        _buildStatCard('Read', '$read', Icons.remove_red_eye, Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard('Failed', '$failed', Icons.error_outline, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignTable(BuildContext pageContext, ReportLoaded state, List<Map<String, dynamic>> campaigns) {
    if (campaigns.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              _dateRange != null || _templateFilter != 'all'
                  ? 'No campaigns found for the selected filters.'
                  : 'Start a campaign to see results here.',
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: campaigns.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (itemCtx, index) {
          final campaign = campaigns[index];
          final dynamic timestamp = campaign['timestamp'];
          final DateTime date;
          if (timestamp is String) {
            date = (DateTime.tryParse(timestamp) ?? DateTime.now()).toLocal();
          } else if (timestamp is int) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
          } else {
            date = DateTime.now();
          }
          final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(date);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            title: Row(
              children: [
                Text('Campaign ${campaign['template']}'),
                const SizedBox(width: 8),
                _buildRetryStatusBadge(
                  campaign['status'] as String?,
                  hasPendingRetry: campaign['hasPendingRetry'] as bool? ?? false,
                ),
              ],
            ),
            subtitle: Text('Sent: $dateStr'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniStat('Sent', '${campaign['successCount'] ?? 0}', Colors.blue),
                const SizedBox(width: 12),
                _buildMiniStat('Delivered', '${campaign['deliveredCount'] ?? 0}', Colors.green),
                const SizedBox(width: 12),
                _buildMiniStat('Read', '${campaign['readCount'] ?? 0}', Colors.orange),
                const SizedBox(width: 12),
                _buildMiniStat('Failed', '${campaign['failureCount']}', Colors.red),
                const SizedBox(width: 12),
                if (_hasRetryPhases(campaign))
                  IconButton(
                    tooltip: 'Phase Report',
                    icon: const Icon(Icons.analytics_outlined,
                        color: AppTheme.primaryColor),
                    onPressed: () {
                      showDialog(
                        context: pageContext,
                        builder: (_) => PhaseReportDialog(
                          campaignId: campaign['id'] as String? ?? '',
                          campaignTemplate:
                              campaign['template'] as String? ?? '-',
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: pageContext,
                      builder: (_) => CampaignDetailDialog(campaign: campaign),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  bool _hasRetryPhases(Map<String, dynamic> campaign) {
    final phases = campaign['retryConfig']?['phases'] as List?;
    return phases != null && phases.isNotEmpty;
  }

  Widget _buildRetryStatusBadge(String? status, {bool hasPendingRetry = false}) {
    // Campaigns actively retrying (DB status = 'retrying')
    if (status == 'retrying') {
      return _statusBadge('Retrying', Icons.replay_outlined, Colors.orange);
    }
    // Campaigns with a scheduled pending retry phase (status still 'initial' but retry queued)
    if (hasPendingRetry) {
      return _statusBadge('Retrying', Icons.replay_outlined, Colors.orange);
    }
    if (status == null || status == 'initial') return const SizedBox.shrink();
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle_outline;
        break;
      case 'error':
        color = Colors.red;
        label = 'Error';
        icon = Icons.error_outline;
        break;
      default:
        return const SizedBox.shrink();
    }
    return _statusBadge(label, icon, color);
  }

  Widget _statusBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date range filter button — same pattern as leads screen
// ---------------------------------------------------------------------------

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange?> onChanged;
  final VoidCallback onClear;

  const _DateRangeButton({
    required this.dateRange,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasRange = dateRange != null;
    final label = hasRange
        ? '${DateFormat('dd/MM/yy').format(dateRange!.start)} – ${DateFormat('dd/MM/yy').format(dateRange!.end)}'
        : 'Date Range';

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showCompactDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: dateRange,
        );
        onChanged(picked);
      },
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasRange ? AppTheme.primaryColor : Colors.grey.shade600,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: hasRange ? AppTheme.primaryColor : Colors.grey.shade700,
            ),
          ),
          if (hasRange) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
            ),
          ],
        ],
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: hasRange
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : Colors.grey.shade300,
        ),
        backgroundColor: hasRange
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
