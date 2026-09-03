import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/reports/presentation/bloc/report_bloc.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/campaign_report_dialog.dart';
import 'package:iFloraBuzz/features/reports/presentation/widgets/report_download_dialog.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange? _dateRange;
  String _templateFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250) {
        final reportBloc = context.read<ReportBloc>();
        final state = reportBloc.state;
        if (state is ReportLoaded && state.hasMore && !state.isLoadingMore) {
          reportBloc.add(FetchNextPageReports());
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSearchField({double? width, bool isMobile = false}) {
    final field = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: TextStyle(fontSize: isMobile ? 12 : 13),
      decoration: InputDecoration(
        hintText: 'Search campaign...',
        hintStyle: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey.shade500),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 8 : 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6), width: 1.5),
        ),
        prefixIcon: Icon(Icons.search, size: isMobile ? 16 : 18, color: Colors.grey.shade600),
        prefixIconConstraints: BoxConstraints(minWidth: isMobile ? 32 : 36, minHeight: 0),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 14),
                splashRadius: 14,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }

  Widget _buildTemplateDropdown({
    required List<String> templateOptions,
    double? width,
    bool isMobile = false,
  }) {
    final validValue = templateOptions.contains(_templateFilter) ? _templateFilter : 'all';

    final dropdown = DropdownButtonFormField<String>(
      initialValue: validValue,
      isExpanded: true,
      style: TextStyle(
        fontSize: isMobile ? 12 : 13,
        color: Colors.black87,
      ),
      selectedItemBuilder: (BuildContext context) {
        return [
          Text(
            'All Templates',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          ...templateOptions.map((t) => Text(
                t,
                style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )),
        ];
      },
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 8 : 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: 'all',
          child: Text(
            'All Templates',
            style: TextStyle(fontSize: isMobile ? 12 : 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...templateOptions.map(
          (t) => DropdownMenuItem(
            value: t,
            child: Text(
              t,
              style: TextStyle(fontSize: isMobile ? 12 : 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _templateFilter = v ?? 'all'),
    );

    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }
    return dropdown;
  }

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
            // Derive unique template names from state.availableTemplates (overall tenant list) & current loaded campaigns
            final allTemplatesSet = <String>{
              ...state.availableTemplates,
              ...state.campaigns
                  .map((c) => c['template'] as String? ?? '')
                  .where((t) => t.isNotEmpty),
            };
            final templateOptions = allTemplatesSet.toList()..sort();

            // Filter campaigns client-side if filters are applied
            final filtered = state.campaigns.where((c) {
              // Search query filter
              if (_searchQuery.trim().isNotEmpty) {
                final query = _searchQuery.trim().toLowerCase();
                final t = (c['template'] as String? ?? '').toLowerCase();
                if (!t.contains(query)) return false;
              }
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

            final isMobile = ResponsiveHelper.isMobile(ctx);
            final isTablet = ResponsiveHelper.isTablet(ctx);

            return RefreshIndicator(
              onRefresh: () async {
                ctx.read<ReportBloc>().add(FetchReportHistory(isRefresh: true));
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 20 : 32)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile || isTablet) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Campaign Reports',
                              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                              overflow: TextOverflow.ellipsis,
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
                                    ctx.read<ReportBloc>().add(FetchReportHistory(isRefresh: true)),
                                tooltip: 'Reload History',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSearchField(isMobile: true),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTemplateDropdown(
                              templateOptions: templateOptions,
                              width: 170,
                              isMobile: true,
                            ),
                            const SizedBox(width: 8),
                            _DateRangeButton(
                              dateRange: _dateRange,
                              onChanged: (r) => setState(() => _dateRange = r),
                              onClear: () => setState(() => _dateRange = null),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Campaign Reports',
                            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildSearchField(width: 200),
                                  const SizedBox(width: 8),
                                  _buildTemplateDropdown(
                                    templateOptions: templateOptions,
                                    width: 180,
                                  ),
                                  const SizedBox(width: 8),
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
                                        ctx.read<ReportBloc>().add(FetchReportHistory(isRefresh: true)),
                                    tooltip: 'Reload History',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildStatGrid(state, filtered),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Text(
                          'Recent Campaigns',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_dateRange != null || _templateFilter != 'all' || _searchQuery.trim().isNotEmpty) ...[
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
    // When no client-side filter is active, use the overall tenant totals from backend aggregate
    int sent = state.totalSent;
    int delivered = state.totalDelivered;
    int read = state.totalRead;
    int failed = state.totalFailed;

    // If client-side filters (search, template or date range) are actively selected, calculate based on filtered subset
    if (_searchQuery.trim().isNotEmpty || _templateFilter != 'all' || _dateRange != null) {
      sent = 0;
      delivered = 0;
      read = 0;
      failed = 0;
      for (final c in campaigns) {
        sent += (c['totalCount'] as num? ?? c['successCount'] as num? ?? 0).toInt();
        delivered += (c['deliveredCount'] as num? ?? 0).toInt();
        read += (c['readCount'] as num? ?? 0).toInt();
        failed += (c['failureCount'] as num? ?? 0).toInt();
      }
    }

    final isMobileOrTablet = !ResponsiveHelper.isDesktop(context);
    final cards = [
      _buildStatCardItem('Total Sent', '$sent', Icons.send, Colors.blue),
      _buildStatCardItem('Delivered', '$delivered', Icons.done_all, Colors.green),
      _buildStatCardItem('Read', '$read', Icons.remove_red_eye, Colors.orange),
      _buildStatCardItem('Failed', '$failed', Icons.error_outline, Colors.red),
    ];

    if (isMobileOrTablet) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: cards,
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: c,
      ))).toList(),
    );
  }

  Widget _buildStatCardItem(String label, String value, IconData icon, Color color) {
    return Card(
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
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignTable(BuildContext pageContext, ReportLoaded state, List<Map<String, dynamic>> campaigns) {
    if (campaigns.isEmpty && !state.isLoadingMore) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              _dateRange != null || _templateFilter != 'all' || _searchQuery.trim().isNotEmpty
                  ? 'No campaigns found for the selected filters.'
                  : 'Start a campaign to see results here.',
            ),
          ),
        ),
      );
    }

    final isMobileOrTablet = !ResponsiveHelper.isDesktop(pageContext);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListView.separated(
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

              if (isMobileOrTablet) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Campaign ${campaign['template']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRetryStatusBadge(
                            campaign['status'] as String?,
                            hasPendingRetry: campaign['hasPendingRetry'] as bool? ?? false,
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
                      const SizedBox(height: 4),
                      Text(
                        'Sent: $dateStr',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Sent', '${campaign['totalCount'] ?? campaign['successCount'] ?? 0}', Colors.blue),
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
                    Flexible(
                      child: Text(
                        'Campaign ${campaign['template']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                    _buildMiniStat('Sent', '${campaign['totalCount'] ?? campaign['successCount'] ?? 0}', Colors.blue),
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
          if (state.isLoadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading more campaigns...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (!state.hasMore && campaigns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Showing all ${campaigns.length} recent campaigns',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
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
    if (status == 'completed') {
      return _statusBadge('Completed', Icons.check_circle_outline, Colors.green);
    }
    if (status == 'error') {
      return _statusBadge('Error', Icons.error_outline, Colors.red);
    }
    // Campaigns actively retrying (DB status = 'retrying')
    if (status == 'retrying') {
      return _statusBadge('Retrying', Icons.replay_outlined, Colors.orange);
    }
    // Campaigns with a scheduled pending retry phase (status still 'initial' but retry queued)
    if (hasPendingRetry) {
      return _statusBadge('Retrying', Icons.replay_outlined, Colors.orange);
    }
    if (status == null || status == 'initial') return const SizedBox.shrink();
    return const SizedBox.shrink();
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
