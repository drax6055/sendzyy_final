import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class ScheduledCampaignsPage extends StatefulWidget {
  const ScheduledCampaignsPage({super.key});

  @override
  State<ScheduledCampaignsPage> createState() => _ScheduledCampaignsPageState();
}

class _ScheduledCampaignsPageState extends State<ScheduledCampaignsPage> {
  List<Map<String, dynamic>> _campaigns = [];
  bool _loading = true;

  // Filters
  String _statusFilter = 'all';
  String _templateFilter = 'all';
  DateTimeRange? _dateRange;

  List<String> get _templateOptions {
    final templates =
        _campaigns
            .map((c) => c['template'] as String? ?? '')
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return templates;
  }

  List<Map<String, dynamic>> get _filtered {
    return _campaigns.where((c) {
      final status = c['status'] as String? ?? '';
      if (_statusFilter != 'all' && status != _statusFilter) return false;

      final template = c['template'] as String? ?? '';
      if (_templateFilter != 'all' && template != _templateFilter) return false;

      if (_dateRange != null) {
        final raw = c['scheduledAt'];
        final DateTime? date = raw == null
            ? null
            : raw is DateTime
            ? raw
            : DateTime.tryParse(raw.toString());
        if (date == null) return false;
        final local = date.toLocal();
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        if (local.isBefore(start) || local.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final repo = getIt<WhatsAppRepository>();
      final list = await repo.fetchScheduledCampaigns();
      setState(() {
        _campaigns = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Campaign'),
        content: const Text(
          'Are you sure you want to cancel this scheduled campaign?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = getIt<WhatsAppRepository>();
    final ok = await repo.cancelScheduledCampaign(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Campaign cancelled' : 'Failed to cancel')),
      );
      if (ok) _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 20 : 32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile || isTablet) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Campaigns',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Campaigns queued for future delivery',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 135,
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'running', child: Text('Running', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'completed', child: Text('Completed', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'failed', child: Text('Failed', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _templateOptions.contains(_templateFilter) ? _templateFilter : 'all',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Templates', style: TextStyle(fontSize: 12)),
                        ),
                        ..._templateOptions.map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _templateFilter = v ?? 'all'),
                    ),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduled Campaigns',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    Text(
                      'Campaigns queued for future delivery',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'running', child: Text('Running')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: _templateOptions.contains(_templateFilter) ? _templateFilter : 'all',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Templates'),
                      ),
                      ..._templateOptions.map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _templateFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 10),
                _DateRangeButton(
                  dateRange: _dateRange,
                  onChanged: (r) => setState(() => _dateRange = r),
                  onClear: () => setState(() => _dateRange = null),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 72,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _campaigns.isEmpty
                          ? 'No scheduled campaigns yet'
                          : 'No campaigns match the selected filters',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_campaigns.isEmpty)
                      Text(
                        'Use "Schedule for later" in Broadcast  to queue a campaign.',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _CampaignCard(
                  data: _filtered[i],
                  onCancel: () =>
                      _cancel(_filtered[i]['id'] ?? _filtered[i]['_id'] ?? ''),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCancel;

  const _CampaignCard({required this.data, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final scheduledAt = _parseDate(data['scheduledAt']);
    final recipientCount = (data['recipients'] as List?)?.length ?? 0;
    final template = data['template'] as String? ?? '-';
    final name = (data['campaignName'] as String?)?.isNotEmpty == true
        ? data['campaignName'] as String
        : 'Campaign';

    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 36 : 44,
            height: isMobile ? 36 : 44,
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(status),
              color: _statusColor(status),
              size: isMobile ? 16 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 13 : 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: isMobile ? 8 : 16,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.description_outlined,
                      label: template,
                    ),
                    _InfoChip(
                      icon: Icons.people_outline,
                      label: '$recipientCount recipients',
                    ),
                    if (scheduledAt != null)
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(scheduledAt),
                      ),
                    if (status == 'completed') ...[
                      _InfoChip(
                        icon: Icons.send,
                        label: '${data['totalCount'] ?? recipientCount} sent',
                        color: Colors.blue,
                      ),
                      _InfoChip(
                        icon: Icons.done_all,
                        label: '${data['deliveredCount'] ?? 0} delivered',
                        color: Colors.green,
                      ),
                      _InfoChip(
                        icon: Icons.remove_red_eye,
                        label: '${data['readCount'] ?? 0} read',
                        color: Colors.orange,
                      ),
                      _InfoChip(
                        icon: Icons.cancel_outlined,
                        label: '${data['failureCount'] ?? 0} failed',
                        color: Colors.red,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (status == 'pending')
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $h:$m';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'running':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'running':
        return Icons.send_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange,
      'running': Colors.blue,
      'completed': Colors.green,
      'failed': Colors.red,
      'cancelled': Colors.grey,
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
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
