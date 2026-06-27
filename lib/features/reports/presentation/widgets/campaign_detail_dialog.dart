import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/reports/presentation/utils/pdf_utils.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';

class CampaignDetailDialog extends StatefulWidget {
  final Map<String, dynamic> campaign;

  const CampaignDetailDialog({super.key, required this.campaign});

  @override
  State<CampaignDetailDialog> createState() => _CampaignDetailDialogState();
}

class _CampaignDetailDialogState extends State<CampaignDetailDialog> {
  late Future<List<Map<String, dynamic>>> _recipientsFuture;
  String _filter = 'all';
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    final campaignId = widget.campaign['id'] as String? ?? '';
    _recipientsFuture = getIt<WhatsAppRepository>().getCampaignRecipients(campaignId);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'read': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'failed': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'read': return Icons.remove_red_eye;
      case 'delivered': return Icons.done_all;
      case 'failed': return Icons.error_outline;
      default: return Icons.send;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final sent = c['successCount'] as int? ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: AppTheme.secondaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campaign: ${c['template'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor),
                        ),
                        Text(
                          c['timestamp'] != null
                              ? () {
                                  final raw = c['timestamp'].toString();
                                  final dt = DateTime.tryParse(raw)?.toLocal();
                                  return dt != null
                                      ? '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
                                      : raw.substring(0, raw.length >= 16 ? 16 : raw.length);
                                }()
                              : '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _recipientsFuture,
                    builder: (context, snapshot) {
                      final recipients = snapshot.data ?? [];
                      return _isDownloading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Download Report',
                              icon: const Icon(Icons.download_outlined),
                              onPressed: snapshot.connectionState == ConnectionState.done
                                  ? () async {
                                      setState(() => _isDownloading = true);
                                      try {
                                        await PdfUtils.generateCampaignDetailReport(
                                          campaign: widget.campaign,
                                          recipients: recipients,
                                        );
                                      } finally {
                                        if (mounted) setState(() => _isDownloading = false);
                                      }
                                    }
                                  : null,
                            );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Recipients list + chips derived from same data
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _recipientsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final all = snapshot.data ?? [];

                  // Derive counts from actual recipient data
                  int delivered = 0, read = 0, failed = 0;
                  for (final r in all) {
                    final s = r['status'] as String? ?? 'sent';
                    if (s == 'delivered') delivered++;
                    if (s == 'read') read++;
                    if (s == 'failed') failed++;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats chips — derived from recipients subcollection
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          children: [
                            _statChip('Sent', sent, Colors.blue),
                            const SizedBox(width: 8),
                            _statChip('Delivered', delivered, Colors.green),
                            const SizedBox(width: 8),
                            _statChip('Read', read, Colors.orange),
                            const SizedBox(width: 8),
                            _statChip('Failed', failed, Colors.red),
                          ],
                        ),
                      ),

                      // Filter tabs
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['all', 'sent', 'delivered', 'read', 'failed']
                                .map((f) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(f[0].toUpperCase() + f.substring(1)),
                                        selected: _filter == f,
                                        onSelected: (_) => setState(() => _filter = f),
                                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(height: 1),

                      // List
                      Expanded(child: _buildList(all)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> all) {
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

                  final filtered = _filter == 'all'
                      ? all
                      : all.where((r) => (r['status'] ?? 'sent') == _filter).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No recipients with status "$_filter"',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: _statusColor(status).withValues(alpha: 0.1),
                          child: Icon(_statusIcon(status),
                              size: 16, color: _statusColor(status)),
                        ),
                        title: Text(to,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: _buildTimeline(sentAt, deliveredAt, readAt, failedAt),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status)),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      String? sentAt, String? deliveredAt, String? readAt, String? failedAt) {
    final parts = <String>[];
    if (sentAt != null) parts.add('Sent ${_fmt(sentAt)}');
    if (deliveredAt != null) parts.add('Delivered ${_fmt(deliveredAt)}');
    if (readAt != null) parts.add('Read ${_fmt(readAt)}');
    if (failedAt != null) parts.add('Failed ${_fmt(failedAt)}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join(' · '),
        style: const TextStyle(fontSize: 11, color: Colors.grey));
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
