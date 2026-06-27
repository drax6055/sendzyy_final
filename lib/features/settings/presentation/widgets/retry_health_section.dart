import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/retry_repository.dart';
import 'package:intl/intl.dart';

/// Expandable settings tile showing retry system health metrics and
/// a paginated execution log.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4
class RetryHealthSection extends StatefulWidget {
  const RetryHealthSection({super.key});

  @override
  State<RetryHealthSection> createState() => _RetryHealthSectionState();
}

class _RetryHealthSectionState extends State<RetryHealthSection> {
  bool _expanded = true;
  Map<String, dynamic>? _health;
  String? _healthError;
  bool _healthLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHealth();
    _loadLogs(reset: true);
  }

  // Logs
  bool _logsLoading = false;
  List<Map<String, dynamic>> _logs = [];
  String? _logsError;
  int _page = 1;
  int _totalPages = 1;
  final _campaignIdController = TextEditingController();
  String _filterCampaignId = '';

  @override
  void dispose() {
    _campaignIdController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_expanded) {
      setState(() => _expanded = true);
      _loadHealth();
      _loadLogs(reset: true);
    } else {
      setState(() => _expanded = false);
    }
  }

  Future<void> _loadHealth() async {
    setState(() { _healthLoading = true; _healthError = null; });
    try {
      final data = await getIt<RetryRepository>().getSystemHealth();
      if (mounted) setState(() { _health = data; _healthLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _healthError = e.toString(); _healthLoading = false; });
    }
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _logs = [];
    }
    setState(() { _logsLoading = true; _logsError = null; });
    try {
      final repo = getIt<RetryRepository>();
      final result = await repo.getLogs(
        page: _page,
        campaignId: _filterCampaignId.isEmpty ? null : _filterCampaignId,
      );
      final newLogs = List<Map<String, dynamic>>.from(result['logs'] ?? []);
      final pagination = result['pagination'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _logs = reset ? newLogs : [..._logs, ...newLogs];
          _totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;
          _logsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _logsError = e.toString(); _logsLoading = false; });
    }
  }

  void _applyFilter() {
    setState(() => _filterCampaignId = _campaignIdController.text.trim());
    _loadLogs(reset: true);
  }

  void _clearFilter() {
    _campaignIdController.clear();
    setState(() => _filterCampaignId = '');
    _loadLogs(reset: true);
  }

  void _nextPage() {
    if (_page < _totalPages) {
      _page++;
      _loadLogs();
    }
  }

  void _prevPage() {
    if (_page > 1) {
      _page--;
      _loadLogs(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? Colors.deepPurple.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    color: _expanded ? Colors.deepPurple : Colors.blueGrey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retry System Health',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: _expanded ? Colors.deepPurple : Colors.black87,
                          ),
                        ),
                        if (_health != null)
                          Text(
                            '${_health!['pendingRetries'] ?? 0} pending · '
                            '${_health!['executingRetries'] ?? 0} executing · '
                            '${_health!['failedExecutions'] ?? 0} failed (1h)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.chevron_right,
                      color: _expanded ? Colors.deepPurple : Colors.grey,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBody(),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 20),
          _buildHealthMetrics(),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildLogsSection(),
        ],
      ),
    );
  }

  // ── Health metrics ─────────────────────────────────────────────────────────

  Widget _buildHealthMetrics() {
    if (_healthLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_healthError != null) {
      return _errorRow(_healthError!, onRetry: _loadHealth);
    }
    if (_health == null) return const SizedBox.shrink();

    final pending = (_health!['pendingRetries'] as num?)?.toInt() ?? 0;
    final executing = (_health!['executingRetries'] as num?)?.toInt() ?? 0;
    final failed = (_health!['failedExecutions'] as num?)?.toInt() ?? 0;
    final avgDelay = (_health!['averageDelaySeconds'] as num?)?.toDouble();
    final lastExec = _health!['lastExecutionTime'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Live Metrics',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            _refreshButton(_loadHealth),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metricCard('Pending', '$pending', Icons.schedule_outlined, Colors.orange),
            const SizedBox(width: 10),
            _metricCard('Executing', '$executing', Icons.play_circle_outline, Colors.blue),
            const SizedBox(width: 10),
            _metricCard('Failed (1h)', '$failed', Icons.error_outline,
                failed > 0 ? Colors.red : Colors.green),
            const SizedBox(width: 10),
            _metricCard(
              'Avg Delay',
              avgDelay != null ? '${avgDelay.toStringAsFixed(1)}s' : '—',
              Icons.timer_outlined,
              Colors.purple,
            ),
          ],
        ),
        if (lastExec != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                'Last execution: ${_fmtDateTime(lastExec)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color),
            ),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── Execution logs ─────────────────────────────────────────────────────────

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Execution Logs',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            _refreshButton(() => _loadLogs(reset: true)),
          ],
        ),
        const SizedBox(height: 12),

        // Campaign ID filter
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _campaignIdController,
                decoration: InputDecoration(
                  hintText: 'Filter by Campaign ID (optional)',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  suffixIcon: _filterCampaignId.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: _clearFilter,
                        )
                      : null,
                ),
                onSubmitted: (_) => _applyFilter(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _applyFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Filter', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_logsLoading && _logs.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_logsError != null && _logs.isEmpty)
          _errorRow(_logsError!, onRetry: () => _loadLogs(reset: true))
        else if (_logs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.list_alt_outlined,
                      size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No log entries found',
                      style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else ...[
          ..._logs.map((log) => _buildLogRow(log)),
          if (_logsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          // Pagination
          if (_totalPages > 1) _buildPagination(),
        ],
      ],
    );
  }

  Widget _buildLogRow(Map<String, dynamic> log) {
    final event = log['event'] as String? ?? 'unknown';
    final campaignId = log['campaignId'] as String? ?? '-';
    final phaseNum = (log['phaseNumber'] as num?)?.toInt() ?? 0;
    final timestamp = log['timestamp'] as String?;
    final details = log['details'] as Map<String, dynamic>? ?? {};
    final errorMsg = details['errorMessage'] as String?;

    Color eventColor;
    IconData eventIcon;
    switch (event) {
      case 'phase_executed':
        eventColor = Colors.green;
        eventIcon = Icons.check_circle_outline;
        break;
      case 'phase_executing':
        eventColor = Colors.blue;
        eventIcon = Icons.play_circle_outline;
        break;
      case 'phase_failed':
        eventColor = Colors.red;
        eventIcon = Icons.error_outline;
        break;
      case 'phase_cancelled':
        eventColor = Colors.grey;
        eventIcon = Icons.cancel_outlined;
        break;
      default:
        eventColor = Colors.orange;
        eventIcon = Icons.schedule_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: eventColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: eventColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(eventIcon, size: 14, color: eventColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Event label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: eventColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _eventLabel(event),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: eventColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phase $phaseNum',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Campaign: $campaignId',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (errorMsg != null && errorMsg.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorMsg,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            timestamp != null ? _fmtDateTime(timestamp) : '—',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1 ? _prevPage : null,
            iconSize: 20,
          ),
          Text(
            'Page $_page of $_totalPages',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages ? _nextPage : null,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _refreshButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text('Refresh',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _errorRow(String msg, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  String _eventLabel(String event) {
    switch (event) {
      case 'phase_executed': return 'Executed';
      case 'phase_executing': return 'Executing';
      case 'phase_failed': return 'Failed';
      case 'phase_cancelled': return 'Cancelled';
      case 'phase_scheduled': return 'Scheduled';
      default: return event;
    }
  }

  String _fmtDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM, HH:mm:ss').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
