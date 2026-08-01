import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/core/widgets/compact_date_range_picker.dart';
import 'package:sendzyy/features/reports/presentation/bloc/report_bloc.dart';
import 'package:sendzyy/features/reports/presentation/widgets/campaign_report_dialog.dart';
import 'package:sendzyy/features/reports/presentation/widgets/report_download_dialog.dart';

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Campaign Reports',
                                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                    ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: templateOptions.contains(_templateFilter) ? _templateFilter : 'all',
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('All Templates', overflow: TextOverflow.ellipsis)),
                                    ...templateOptions.map(
                                      (t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() => _templateFilter = v ?? 'all'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DateRangeButton(
                                  dateRange: _dateRange,
                                  onChanged: (r) => setState(() => _dateRange = r),
                                  onClear: () => setState(() => _dateRange = null),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
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
                        ],
                        const SizedBox(height: 24),
                        _buildStatGrid(state, filtered, isMobile),
                        const SizedBox(height: 24),
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
                        _buildCampaignTable(ctx, state, filtered, isMobile),
                      ],
                    ),
                  );
                },
              ),
            );
          }
          return const Center(child: Text('No reports available yet.'));
        },
      ),
    );
  }

  Widget _buildStatGrid(ReportLoaded state, List<Map<String, dynamic>> campaigns, bool isMobile) {
    // Compute stats from filtered campaigns
    int sent = 0, delivered = 0, read = 0, failed = 0;
    for (final c in campaigns) {
      sent += (c['totalCount'] as num? ?? 0).toInt();
      delivered += (c['deliveredCount'] as num? ?? 0).toInt();
      read += (c['readCount'] as num? ?? 0).toInt();
      failed += (c['failureCount'] as num? ?? 0).toInt();
    }

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              _buildStatCard('Total Sent', '$sent', Icons.send, Colors.blue),
              const SizedBox(width: 12),
              _buildStatCard('Delivered', '$delivered', Icons.done_all, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Read', '$read', Icons.remove_red_eye, Colors.orange),
              const SizedBox(width: 12),
              _buildStatCard('Failed', '$failed', Icons.error_outline, Colors.red),
            ],
          ),
        ],
      );
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignTable(BuildContext pageContext, ReportLoaded state, List<Map<String, dynamic>> campaigns, bool isMobile) {
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

          if (isMobile) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Campaign ${campaign['template']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            _buildRetryStatusBadge(
                              campaign['status'] as String?,
                              hasPendingRetry: campaign['hasPendingRetry'] as bool? ?? false,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'View Report',
                        icon: const Icon(Icons.analytics_outlined, color: AppTheme.primaryColor),
                        onPressed: () {
                          showDialog(
                            context: pageContext,
                            builder: (_) => CampaignReportDialog(campaign: campaign),
                          );
                        },
                      ),
                    ],
                  ),
                  Text('Sent: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Sent', '${campaign['totalCount'] ?? 0}', Colors.blue),
                      _buildMiniStat('Delivered', '${((campaign['deliveredCount'] as num? ?? 0).toInt()).clamp(0, 9999999)}', Colors.green),
                      _buildMiniStat('Read', '${campaign['readCount'] ?? 0}', Colors.orange),
                      _buildMiniStat('Failed', '${campaign['failureCount'] ?? 0}', Colors.red),
                    ],
                  ),
                ],
              ),
            );
          }

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
                _buildMiniStat('Sent', '${campaign['totalCount'] ?? 0}', Colors.blue),
                const SizedBox(width: 12),
                _buildMiniStat('Delivered', '${((campaign['deliveredCount'] as num? ?? 0).toInt()).clamp(0, 9999999)}', Colors.green),
                const SizedBox(width: 12),
                _buildMiniStat('Read', '${campaign['readCount'] ?? 0}', Colors.orange),
                const SizedBox(width: 12),
                _buildMiniStat('Failed', '${campaign['failureCount'] ?? 0}', Colors.red),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'View Report',
                  icon: const Icon(Icons.analytics_outlined,
                      color: AppTheme.primaryColor),
                  onPressed: () {
                    showDialog(
                      context: pageContext,
                      builder: (_) => CampaignReportDialog(campaign: campaign),
                    );
                  },
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

    return OutlinedButton(
      onPressed: () async {
        final picked = await showCompactDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: dateRange,
        );
        onChanged(picked);
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: hasRange
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : Colors.grey.shade300,
        ),
        backgroundColor: hasRange
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.date_range,
            size: 16,
            color: hasRange ? AppTheme.primaryColor : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: hasRange ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
          ),
          if (hasRange) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
            ),
          ],
        ],
      ),
    );
  }
}

