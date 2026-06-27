import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/widgets/compact_date_range_picker.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class LeadModel {
  final String id;
  final String tenantId;
  final String name;
  final String mobileNumber;
  final String email;
  final String companyName;
  final String source;
  final String formName;
  final Map<String, dynamic> metadata;
  final String status;
  final String? clientId;
  final bool isDuplicate;
  final DateTime createdAt;

  const LeadModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.companyName,
    required this.source,
    required this.formName,
    required this.metadata,
    required this.status,
    this.clientId,
    required this.isDuplicate,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> j) => LeadModel(
        id: j['_id']?.toString() ?? '',
        tenantId: j['tenantId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        mobileNumber: j['mobileNumber']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        companyName: j['companyName']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        formName: j['formName']?.toString() ?? '',
        metadata: (j['metadata'] as Map<String, dynamic>?) ?? {},
        status: j['status']?.toString() ?? 'new',
        clientId: j['clientId']?.toString(),
        isDuplicate: j['isDuplicate'] == true,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  LeadModel copyWith({String? status}) => LeadModel(
        id: id,
        tenantId: tenantId,
        name: name,
        mobileNumber: mobileNumber,
        email: email,
        companyName: companyName,
        source: source,
        formName: formName,
        metadata: metadata,
        status: status ?? this.status,
        clientId: clientId,
        isDuplicate: isDuplicate,
        createdAt: createdAt,
      );

  /// Extracts the message/note field from metadata (CF7, Gravity Forms, custom)
  String get message {
    final m = metadata;
    return (m['message'] ?? m['your-message'] ?? m['msg'] ?? m['note'] ?? m['notes'] ?? m['comment'] ?? '').toString();
  }
}

// ---------------------------------------------------------------------------
// Analytics model
// ---------------------------------------------------------------------------

class LeadAnalytics {
  final int totalLeads;
  final int leadsToday;
  final int leadsThisWeek;
  final int shopifyCount;
  final int wordpressCount;
  final int newCount;
  final int contactedCount;
  final int convertedCount;
  final int failedCount;
  final List<DailyBucket> dailyBuckets;

  const LeadAnalytics({
    required this.totalLeads,
    required this.leadsToday,
    required this.leadsThisWeek,
    required this.shopifyCount,
    required this.wordpressCount,
    required this.newCount,
    required this.contactedCount,
    required this.convertedCount,
    required this.failedCount,
    required this.dailyBuckets,
  });
}

class DailyBucket {
  final DateTime date;
  final int shopify;
  final int wordpress;

  const DailyBucket({required this.date, required this.shopify, required this.wordpress});
}

// ---------------------------------------------------------------------------
// Page widget
// ---------------------------------------------------------------------------

class LeadManagementPage extends StatefulWidget {
  const LeadManagementPage({super.key});

  @override
  State<LeadManagementPage> createState() => _LeadManagementPageState();
}

class _LeadManagementPageState extends State<LeadManagementPage> {
  final Dio _dio = getIt<Dio>();

  // Leads list state
  List<LeadModel> _leads = [];
  bool _loading = true;
  String? _error;

  // Analytics state
  LeadAnalytics? _analytics;

  // Filters
  String _sourceFilter = 'all';
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;
  final TextEditingController _searchCtrl = TextEditingController();

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLeads();
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        if (_sourceFilter != 'all') 'source': _sourceFilter,
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_searchCtrl.text.isNotEmpty) 'search': _searchCtrl.text,
        if (_dateRange != null)
          'startDate': _dateRange!.start.toIso8601String(),
        if (_dateRange != null)
          'endDate': _dateRange!.end.toIso8601String(),
      };

      final response = await _dio.get('/api/leads', queryParameters: params);
      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> items;
        if (data is List) {
          items = data;
        } else if (data is Map && data['leads'] != null) {
          items = data['leads'] as List;
        } else {
          items = [];
        }
        final fetched = items.map((e) => LeadModel.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _leads = fetched;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final response = await _dio.get('/api/leads/analytics');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final bySource = (data['bySource'] as Map<String, dynamic>?) ?? {};
        final byStatus = (data['byStatus'] as Map<String, dynamic>?) ?? {};
        final daily = (data['daily'] as List<dynamic>?) ?? [];

        final buckets = <DailyBucket>[];
        for (final d in daily) {
          final m = d as Map<String, dynamic>;
          buckets.add(DailyBucket(
            date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
            shopify: (m['shopify'] as num?)?.toInt() ?? 0,
            wordpress: (m['wordpress'] as num?)?.toInt() ?? 0,
          ));
        }

        setState(() {
          _analytics = LeadAnalytics(
            totalLeads: (data['totalLeads'] as num?)?.toInt() ?? 0,
            leadsToday: (data['leadsToday'] as num?)?.toInt() ?? 0,
            leadsThisWeek: (data['leadsThisWeek'] as num?)?.toInt() ?? 0,
            shopifyCount: (bySource['shopify'] as num?)?.toInt() ?? 0,
            wordpressCount: (bySource['wordpress'] as num?)?.toInt() ?? 0,
            newCount: (byStatus['new'] as num?)?.toInt() ?? 0,
            contactedCount: (byStatus['contacted'] as num?)?.toInt() ?? 0,
            convertedCount: (byStatus['converted'] as num?)?.toInt() ?? 0,
            failedCount: (byStatus['failed'] as num?)?.toInt() ?? 0,
            dailyBuckets: buckets,
          );
        });
      }
    } catch (_) {
      // analytics are non-critical
    }
  }

  Future<void> _updateStatus(LeadModel lead, String newStatus) async {
    try {
      await _dio.patch(
        '/api/leads/${lead.id}/status',
        data: {'status': newStatus},
      );
      setState(() {
        final idx = _leads.indexWhere((l) => l.id == lead.id);
        if (idx != -1) _leads[idx] = _leads[idx].copyWith(status: newStatus);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  void _applyFilters() => _fetchLeads();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: title + filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Leads',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                ),
                 const SizedBox(width: 10),
                Expanded(
                  child: _FilterBar(
                  sourceFilter: _sourceFilter,
                  statusFilter: _statusFilter,
                  dateRange: _dateRange,
                  searchCtrl: _searchCtrl,
                  onSourceChanged: (v) {
                    setState(() => _sourceFilter = v);
                    _applyFilters();
                  },
                  onStatusChanged: (v) {
                    setState(() => _statusFilter = v);
                    _applyFilters();
                  },
                  onDateRangeChanged: (r) {
                    setState(() => _dateRange = r);
                    _applyFilters();
                  },
                  onSearchChanged: (_) => _applyFilters(),
                  onClearDate: () {
                    setState(() => _dateRange = null);
                    _applyFilters();
                  },
                ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: status chips
            _StatusCountsRow(leads: _leads),
            const SizedBox(height: 20),

            // Analytics summary + chart
            if (_analytics != null) ...[
              _SummaryRow(analytics: _analytics!),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _BarChart(analytics: _analytics!)),
                  const SizedBox(width: 16),
                  SizedBox(width: 220, child: _FunnelWidget(analytics: _analytics!)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 16),

            // List
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchLeads(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_leads.isEmpty) return _EmptyState(onSetup: () {});

    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: _leads.length,
      itemBuilder: (context, i) {
        final lead = _leads[i];
        return _LeadRow(
          lead: lead,
          onTap: () => _showDetailSheet(lead),
          onStatusChanged: (s) => _updateStatus(lead, s),
        );
      },
    );
  }

  void _showDetailSheet(LeadModel lead) {
    showDialog(
      context: context,
      builder: (_) => _LeadDetailDialog(
        lead: lead,
        onDelete: () async {
          try {
            await _dio.delete('/api/leads/${lead.id}');
            if (mounted) {
              setState(() => _leads.removeWhere((l) => l.id == lead.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lead deleted')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar widget
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final String sourceFilter;
  final String statusFilter;
  final DateTimeRange? dateRange;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearDate;

  const _FilterBar({
    required this.sourceFilter,
    required this.statusFilter,
    required this.dateRange,
    required this.searchCtrl,
    required this.onSourceChanged,
    required this.onStatusChanged,
    required this.onDateRangeChanged,
    required this.onSearchChanged,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search - expanded to fill available space
        Expanded(
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search name or mobile...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                    )
                  : Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Source dropdown
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            value: sourceFilter,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Sources')),
              DropdownMenuItem(value: 'shopify', child: Text('Shopify')),
              DropdownMenuItem(value: 'wordpress', child: Text('WordPress')),
            ],
            onChanged: (v) => onSourceChanged(v ?? 'all'),
          ),
        ),
        const SizedBox(width: 8),
        // Status dropdown
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            value: statusFilter,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'new', child: Text('New')),
              DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
              DropdownMenuItem(value: 'converted', child: Text('Converted')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
            ],
            onChanged: (v) => onStatusChanged(v ?? 'all'),
          ),
        ),
        const SizedBox(width: 8),
        // Date range picker
        _DateRangeButton(
          dateRange: dateRange,
          onChanged: onDateRangeChanged,
          onClear: onClearDate,
        ),
        const SizedBox(width: 8),
        // Search

      ],
    );
  }
}

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
    final label = dateRange == null
        ? 'Date Range'
        : '${DateFormat('dd/MM').format(dateRange!.start)} – ${DateFormat('dd/MM').format(dateRange!.end)}';

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
      icon: const Icon(Icons.date_range, size: 16),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          if (dateRange != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 14),
            ),
          ],
        ],
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lead row widget
// ---------------------------------------------------------------------------

class _LeadRow extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChanged;

  const _LeadRow({
    required this.lead,
    required this.onTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                child: Text(
                  lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + mobile
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          lead.name.isNotEmpty ? lead.name : 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (lead.isDuplicate) ...[
                          const SizedBox(width: 6),
                          _Badge(label: 'Duplicate', color: Colors.orange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.mobileNumber,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Source badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SourceBadge(source: lead.source),
                ),
              ),

              // Form name
              Expanded(
                flex: 2,
                child: Text(
                  lead.formName.isNotEmpty ? lead.formName : '—',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Message
              Expanded(
                flex: 3,
                child: lead.message.isNotEmpty
                    ? Text(
                        lead.message,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      )
                    : Text('—', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ),

              // Status dropdown
              Expanded(
                flex: 2,
                child: _StatusDropdown(
                  status: lead.status,
                  onChanged: onStatusChanged,
                ),
              ),

              // Timestamp
              Expanded(
                flex: 2,
                child: Text(
                  DateFormat('dd MMM yy\nHH:mm').format(lead.createdAt.toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isShopify = source.toLowerCase() == 'shopify';
    final color = isShopify ? Colors.green : Colors.blue;
    final label = isShopify ? 'Shopify' : 'WordPress';
    return _Badge(label: label, color: color);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusDropdown({required this.status, required this.onChanged});

  static const _statusColors = {
    'new': Colors.blue,
    'contacted': Colors.orange,
    'converted': Colors.green,
    'failed': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          isDense: true,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          items: const [
            DropdownMenuItem(value: 'new', child: Text('New')),
            DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
            DropdownMenuItem(value: 'converted', child: Text('Converted')),
            DropdownMenuItem(value: 'failed', child: Text('Failed')),
          ],
          onChanged: (v) {
            if (v != null && v != status) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lead detail dialog
// ---------------------------------------------------------------------------

class _LeadDetailDialog extends StatelessWidget {
  final LeadModel lead;
  final Future<void> Function() onDelete;
  const _LeadDetailDialog({required this.lead, required this.onDelete});

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return Colors.blue;
      case 'contacted': return Colors.orange;
      case 'converted': return Colors.green;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(lead.status);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.12),
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name.isNotEmpty ? lead.name : 'Unknown',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _SourceBadge(source: lead.source),
                            _Badge(label: lead.status.toUpperCase(), color: statusColor),
                            if (lead.isDuplicate)
                              _Badge(label: 'Duplicate', color: Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Lead?'),
                          content: const Text('This lead will be permanently deleted.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      Navigator.pop(context);
                      await onDelete();
                    },
                    color: Colors.red.shade400,
                    tooltip: 'Delete lead',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info grid
                    _InfoGrid(lead: lead),

                    if (lead.message.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel('Message'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          lead.message,
                          style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                        ),
                      ),
                    ],

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final LeadModel lead;
  const _InfoGrid({required this.lead});

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Mobile', lead.mobileNumber, Icons.phone_rounded),
      ('Email', lead.email.isNotEmpty ? lead.email : '—', Icons.email_rounded),
      ('Company', lead.companyName.isNotEmpty ? lead.companyName : '—', Icons.business_rounded),
      ('Form', lead.formName.isNotEmpty ? lead.formName : '—', Icons.description_rounded),
      ('Source', lead.source, Icons.integration_instructions_rounded),
      ('Status', lead.status, Icons.flag_rounded),
      ('Created', DateFormat('dd MMM yyyy, HH:mm').format(lead.createdAt.toLocal()), Icons.schedule_rounded),
      if (lead.clientId != null) ('Client ID', lead.clientId!, Icons.badge_rounded),
    ];

    return Column(
      children: fields.map((f) => _InfoRow(icon: f.$3, label: f.$1, value: f.$2)).toList(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.secondaryColor.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.secondaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary counts row (filtered leads)
// ---------------------------------------------------------------------------

class _StatusCountsRow extends StatelessWidget {
  final List<LeadModel> leads;
  const _StatusCountsRow({required this.leads});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      'new': 0,
      'contacted': 0,
      'converted': 0,
      'failed': 0,
    };
    for (final l in leads) {
      counts[l.status] = (counts[l.status] ?? 0) + 1;
    }

    return Row(
      children: [
        _CountChip(label: 'New', count: counts['new']!, color: Colors.blue),
        const SizedBox(width: 8),
        _CountChip(label: 'Contacted', count: counts['contacted']!, color: Colors.orange),
        const SizedBox(width: 8),
        _CountChip(label: 'Converted', count: counts['converted']!, color: Colors.green),
        const SizedBox(width: 8),
        _CountChip(label: 'Failed', count: counts['failed']!, color: Colors.red),
        const SizedBox(width: 8),
        _CountChip(label: 'Total', count: leads.length, color: AppTheme.secondaryColor),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final LeadAnalytics analytics;
  const _SummaryRow({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Total Leads', value: '${analytics.totalLeads}', icon: Icons.contacts_rounded, color: AppTheme.secondaryColor),
        const SizedBox(width: 12),
        _StatCard(label: 'Today', value: '${analytics.leadsToday}', icon: Icons.today_rounded, color: Colors.blue),
        const SizedBox(width: 12),
        _StatCard(label: 'This Week', value: '${analytics.leadsThisWeek}', icon: Icons.date_range_rounded, color: Colors.purple),
        const SizedBox(width: 12),
        _StatCard(label: 'Shopify', value: '${analytics.shopifyCount}', icon: Icons.shopping_bag_rounded, color: Colors.green),
        const SizedBox(width: 12),
        _StatCard(label: 'WordPress', value: '${analytics.wordpressCount}', icon: Icons.language_rounded, color: Colors.blue.shade700),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7-day bar chart (colour-coded by source)
// ---------------------------------------------------------------------------

class _BarChart extends StatelessWidget {
  final LeadAnalytics analytics;
  const _BarChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    // Use last 7 days from analytics or generate empty buckets
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final bucketMap = <String, DailyBucket>{};
    for (final b in analytics.dailyBuckets) {
      final key = DateFormat('yyyy-MM-dd').format(b.date);
      bucketMap[key] = b;
    }

    final maxVal = days.fold<int>(1, (m, d) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      final b = bucketMap[key];
      if (b == null) return m;
      return (b.shopify + b.wordpress) > m ? (b.shopify + b.wordpress) : m;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final key = DateFormat('yyyy-MM-dd').format(d);
                final b = bucketMap[key];
                final shopify = b?.shopify ?? 0;
                final wordpress = b?.wordpress ?? 0;
                final total = shopify + wordpress;
                final barH = maxVal > 0 ? (total / maxVal) * 80 : 0.0;
                final shopifyH = total > 0 ? (shopify / total) * barH : 0.0;
                final wpH = barH - shopifyH;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (total > 0)
                          Text('$total', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shopifyH > 0)
                              Container(
                                height: shopifyH,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            if (wpH > 0)
                              Container(
                                height: wpH,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            if (total == 0)
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM').format(d),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendDot(color: Colors.green, label: 'Shopify'),
              const SizedBox(width: 12),
              _LegendDot(color: Colors.blue, label: 'WordPress'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conversion funnel widget
// ---------------------------------------------------------------------------

class _FunnelWidget extends StatelessWidget {
  final LeadAnalytics analytics;
  const _FunnelWidget({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final newCount = analytics.newCount + analytics.contactedCount + analytics.convertedCount + analytics.failedCount;
    final contactedCount = analytics.contactedCount + analytics.convertedCount;
    final convertedCount = analytics.convertedCount;

    String pct(int num, int denom) {
      if (denom == 0) return '0%';
      return '${(num / denom * 100).toStringAsFixed(1)}%';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Conversion Funnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          _FunnelStep(label: 'New', count: newCount, color: Colors.blue, pct: '100%'),
          _FunnelArrow(pct: pct(contactedCount, newCount)),
          _FunnelStep(label: 'Contacted', count: contactedCount, color: Colors.orange, pct: pct(contactedCount, newCount)),
          _FunnelArrow(pct: pct(convertedCount, contactedCount)),
          _FunnelStep(label: 'Converted', count: convertedCount, color: Colors.green, pct: pct(convertedCount, newCount)),
        ],
      ),
    );
  }
}

class _FunnelStep extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String pct;
  const _FunnelStep({required this.label, required this.count, required this.color, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
          ),
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Text(pct, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _FunnelArrow extends StatelessWidget {
  final String pct;
  const _FunnelArrow({required this.pct});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(pct, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyState({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No leads yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your Shopify store or WordPress site\nto start capturing leads automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onSetup,
            icon: const Icon(Icons.integration_instructions_rounded),
            label: const Text('Set up your first integration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
