import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/auth/presentation/widgets/api_config_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/login_page.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/retry_config_section.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/retry_health_section.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:js_interop';

// JS interop types for the signup result
extension type _SignupResult._(JSObject _) implements JSObject {
  external String get status;
  external String? get code;
  external String? get wabaId;
  external String? get phoneNumberId;
}

@JS()
external JSPromise<_SignupResult> launchWhatsAppSignup();

class SettingsPage extends StatefulWidget {
  final VoidCallback? onRenewPlan;
  const SettingsPage({super.key, this.onRenewPlan});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isConnecting = false;
  bool _showProfileInfo = false;
  Map<String, dynamic>? _profile;
  bool _profileLoading = false;

  bool _showPaymentHistory = false;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _paymentHistoryLoading = false;
  String? _paymentHistoryError;

  void _showManualConfig(BuildContext context, {String? wabaId, String? phoneNumberId}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ApiConfigDialog(
        initialWabaId: wabaId,
        initialPhoneNumberId: phoneNumberId,
      ),
    );
    if (result == true) {
      if (mounted) {
        context.read<TemplateBloc>().add(FetchTemplates());
        context.read<AuthBloc>().add(AuthCheckRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meta Account Connected Successfully')),
        );
      }
    }
  }

  Future<void> _toggleProfileInfo() async {
    if (_showProfileInfo) {
      setState(() => _showProfileInfo = false);
      return;
    }
    setState(() { _showProfileInfo = true; _profileLoading = true; });
    try {
      final profile = await getIt<WhatsAppRepository>().getProfile();
      if (mounted) setState(() { _profile = profile; _profileLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _togglePaymentHistory() async {
    if (_showPaymentHistory) {
      setState(() => _showPaymentHistory = false);
      return;
    }
    setState(() {
      _showPaymentHistory = true;
      _paymentHistoryLoading = true;
      _paymentHistoryError = null;
    });
    try {
      final records = await getIt<WhatsAppRepository>().fetchPaymentHistory();
      if (mounted) {
        setState(() {
          _paymentHistory = records;
          _paymentHistoryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentHistoryError = e.toString();
          _paymentHistoryLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) { return value.toString(); }
  }

  String _daysLeft(dynamic expiresAt) {
    if (expiresAt == null) return 'N/A';
    try {
      final diff = DateTime.parse(expiresAt.toString()).toLocal().difference(DateTime.now()).inDays;
      if (diff < 0) return 'Expired';
      return '$diff days left';
    } catch (_) { return 'N/A'; }
  }

  Color _expiryColor(dynamic expiresAt) {
    if (expiresAt == null) return Colors.grey;
    try {
      final diff = DateTime.parse(expiresAt.toString()).toLocal().difference(DateTime.now()).inDays;
      if (diff < 0) return Colors.red;
      if (diff <= 7) return Colors.orange;
      return Colors.green;
    } catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool isConnected = state is AuthAuthenticated &&
            state.tenant['whatsappConfig'] != null &&
            state.tenant['whatsappConfig']['accessToken'] != null &&
            state.tenant['whatsappConfig']['accessToken'].toString().isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
          color: AppTheme.backgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Meta Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                ),
                const SizedBox(height: 32),

                isConnected
                    ? _buildConnectedDetailsCard(context, state.tenant['whatsappConfig'])
                    : _buildConnectMetaCard(context),

                const SizedBox(height: 32),

                const Text(
                  'Account Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Renew Panel Plan tile
                _buildRenewPlanTile(context),

                const SizedBox(height: 12),

                // Profile Information â€” inline expandable
                _buildExpandableTile(
                  title: 'Profile Information',
                  icon: Icons.person_outline,
                  isExpanded: _showProfileInfo,
                  onTap: _toggleProfileInfo,
                  child: _buildProfileContent(),
                ),

                const SizedBox(height: 12),
                _buildPlaceholderTile('Security & Password', Icons.lock_outline,
                    () => _showChangePasswordDialog(context)),

                const SizedBox(height: 12),
                _buildExpandableTile(
                  title: 'Payment History',
                  icon: Icons.receipt_long_rounded,
                  isExpanded: _showPaymentHistory,
                  onTap: _togglePaymentHistory,
                  child: _buildPaymentHistoryContent(),
                ),


              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRenewPlanTile(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const SizedBox.shrink();
        }
        
        final subscription = authState.tenant['subscription'] as Map<String, dynamic>?;
        final expiryDateStr = subscription?['expiryDate'];
        final expiresAt = expiryDateStr != null ? DateTime.parse(expiryDateStr as String) : null;
        
        final daysLeft = expiresAt != null
            ? expiresAt.difference(DateTime.now()).inDays
            : null;
        final isExpired = daysLeft != null && daysLeft < 0;
        final isWarning = daysLeft != null && daysLeft <= 7 && !isExpired;

        final Color badgeColor = isExpired
            ? Colors.red
            : isWarning
                ? Colors.orange
                : Colors.green;

        final String expiryLabel = expiresAt == null
            ? 'No active plan'
            : isExpired
                ? 'Expired'
                : '$daysLeft day${daysLeft == 1 ? '' : 's'} left';

        final String expiryDateFormatted = expiresAt != null
            ? DateFormat('dd MMM yyyy').format(expiresAt.toLocal())
            : '';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.secondaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel Plan',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (expiresAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Expires $expiryDateFormatted',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              // Days-left badge
              if (daysLeft != null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    expiryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              SizedBox(
                width: 130,
                child: ElevatedButton.icon(
                  onPressed: widget.onRenewPlan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Renew Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired || isWarning
                        ? badgeColor
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandableTile({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(icon, color: isExpanded ? AppTheme.primaryColor : Colors.blueGrey),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: isExpanded ? AppTheme.primaryColor : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.chevron_right,
                      color: isExpanded ? AppTheme.primaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: child,
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_profileLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_profile == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Failed to load profile', style: TextStyle(color: Colors.grey))),
      );
    }

    final sub = _profile!['subscription'];
    final expiresAt = sub?['expiresAt'] ?? sub?['expiryDate'];
    final expiryColor = _expiryColor(expiresAt);
    final daysLeft = _daysLeft(expiresAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 20),

          // â”€â”€ Account Info â”€â”€
          _sectionHeader(Icons.person_outline, 'Account Info'),
          const SizedBox(height: 14),
          _infoRow('Name', _profile!['name']?.toString() ?? 'N/A'),
          _infoRow('Email', _profile!['email']?.toString() ?? 'N/A'),
          _infoRow('Member Since', _formatDate(
            _profile!['createdAt'] ??
            _profile!['subscription']?['lastPaymentDate'],
          )),

          if (sub != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // â”€â”€ Subscription â”€â”€
            _sectionHeader(Icons.workspace_premium, 'Subscription'),
            const SizedBox(height: 14),
            _infoRow('Plan', sub['planName']?.toString() ?? sub['packageName']?.toString() ?? 'N/A'),
            _infoRow('Billing Cycle', _capitalize(sub['billingCycle']?.toString() ?? 'N/A')),
            _infoRow('Price', 'â‚¹${sub['price'] ?? 'N/A'}'),
            _infoRow('Panel Expires', _formatDate(expiresAt)),
            const SizedBox(height: 12),

            // Expiry badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: expiryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: expiryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: expiryColor),
                  const SizedBox(width: 8),
                  Text(
                    daysLeft,
                    style: TextStyle(color: expiryColor, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text('No active subscription', style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  /// Replace characters outside the PDF default font's Latin-1 range.
  String _pdfSafe(String s) => s
      .replaceAll('\u2014', '-')   // em dash â€”
      .replaceAll('\u2013', '-')   // en dash â€“
      .replaceAll('\u2018', "'")   // left single quote '
      .replaceAll('\u2019', "'")   // right single quote '
      .replaceAll('\u201C', '"')   // left double quote "
      .replaceAll('\u201D', '"')   // right double quote "
      .replaceAll('\u2026', '...') // ellipsis â€¦
      .replaceAll(RegExp(r'[^\x00-\xFF]'), '?'); // anything else outside Latin-1

  /// Generate and download a PDF receipt for a single payment record.
  Future<void> _downloadReceipt(Map<String, dynamic> record) async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final isPanelRenewal = record['category'] == 'panel_renewal';
    final description = record['description']?.toString() ?? '';
    final credits = (record['credits'] as num?)?.toDouble() ?? 0;
    final timestamp = record['timestamp'] != null
        ? DateTime.tryParse(record['timestamp'].toString())?.toLocal()
        : null;
    final dateStr = timestamp != null ? fmt.format(timestamp) : 'N/A';
    final typeLabel = isPanelRenewal ? 'Panel Renewal' : 'Credit Purchase';
    final color = isPanelRenewal ? PdfColors.purple : PdfColor.fromHex('#1DB954');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Sendzyy',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color)),
                  pw.Text('Payment Receipt',
                      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey600)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Date: $dateStr',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  pw.Text('Type: $typeLabel',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ]),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: color),
            pw.SizedBox(height: 24),

            // Description box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Description',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(_pdfSafe(description.isNotEmpty ? description : typeLabel),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            pw.SizedBox(height: 20),

            // Details table
            pw.TableHelper.fromTextArray(
              headers: ['Field', 'Value'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: color),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
              data: [
                ['Category', typeLabel],
                ['Date & Time', dateStr],
                if (!isPanelRenewal && credits > 0) ['Credits Added', '+${credits.toStringAsFixed(0)}'],
                ['Status', 'Completed'],
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text('Thank you for your payment.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  /// Generate and download a PDF summary of all payment history.
  Future<void> _downloadAllPayments() async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Sendzyy - Payment History',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated: $now',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ]),
            pw.SizedBox(height: 6),
            pw.Divider(),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Type', 'Credits'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            data: _paymentHistory.map((r) {
              final isPanelRenewal = r['category'] == 'panel_renewal';
              final credits = (r['credits'] as num?)?.toDouble() ?? 0;
              final timestamp = r['timestamp'] != null
                  ? DateTime.tryParse(r['timestamp'].toString())?.toLocal()
                  : null;
              return [
                timestamp != null ? fmt.format(timestamp) : 'N/A',
                _pdfSafe(r['description']?.toString() ?? ''),
                isPanelRenewal ? 'Panel Renewal' : 'Credit Purchase',
                (!isPanelRenewal && credits > 0) ? '+${credits.toStringAsFixed(0)}' : '-',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Widget _buildPaymentHistoryContent() {
    if (_paymentHistoryLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_paymentHistoryError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              const Text('Failed to load history', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextButton(onPressed: _togglePaymentHistory, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final current = _paymentHistory;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (_paymentHistory.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _downloadAllPayments,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined, size: 15, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text('Download All', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),

          if (current.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No records', style: TextStyle(color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            ...current.map((record) => _buildPaymentCard(record, onDownload: () => _downloadReceipt(record))),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> record, {VoidCallback? onDownload}) {
    final isPanelRenewal = record['category'] == 'panel_renewal';
    final description = record['description']?.toString() ?? '';
    final credits = (record['credits'] as num?)?.toDouble() ?? 0;
    final timestamp = record['timestamp'] != null
        ? DateTime.tryParse(record['timestamp'].toString())?.toLocal()
        : null;
    final dateStr = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp)
        : 'N/A';

    final color = isPanelRenewal ? Colors.purple : AppTheme.primaryColor;
    final icon = isPanelRenewal ? Icons.workspace_premium_rounded : Icons.add_shopping_cart_rounded;
    final typeLabel = isPanelRenewal ? 'Panel Renewal' : 'Credit Purchase';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty ? description : typeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(typeLabel,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          if (!isPanelRenewal && credits > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${credits.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
              ),
            ),
          const SizedBox(width: 8),
          // Download receipt button
          InkWell(
            onTap: onDownload,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.download_outlined, size: 18, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryColor)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildConnectMetaCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF1877F2), size: 64),
            const SizedBox(height: 24),
            const Text(
              'Connect your Meta / Facebook Account',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Link your account to enable WhatsApp Cloud API. This allows you to send bulk messages, manage templates, and more.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final result = await launchWhatsAppSignup().toDart;

                  if (result.status == 'success') {
                    setState(() => _isConnecting = true);

                    final wabaId = result.wabaId;
                    final phoneNumberId = result.phoneNumberId;
                    final code = result.code;

                    // If we have no code but have WABA/phone IDs, skip token exchange and go manual config
                    if ((code == null || code.isEmpty) && (wabaId != null || phoneNumberId != null)) {
                      setState(() => _isConnecting = false);
                      if (mounted) {
                        _showManualConfig(context, wabaId: wabaId, phoneNumberId: phoneNumberId);
                      }
                      return;
                    }

                    final response = await getIt<WhatsAppRepository>().facebookEmbeddedSignup(
                      code: code ?? '',
                      appId: '1509853364110343',
                      wabaId: wabaId,
                      phoneNumberId: phoneNumberId,
                    );

                    setState(() => _isConnecting = false);

                    if (response != null && mounted) {
                      final config = response['config'] as Map<String, dynamic>?;
                      final serverWabaId = config?['wabaId']?.toString();
                      final serverPhoneId = config?['phoneNumberId']?.toString();

                      // If server resolved the IDs, refresh auth state
                      if ((serverWabaId != null && serverWabaId.isNotEmpty) &&
                          (serverPhoneId != null && serverPhoneId.isNotEmpty)) {
                        context.read<AuthBloc>().add(AuthCheckRequested());
                        context.read<TemplateBloc>().add(FetchTemplates());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meta Account Connected Successfully!')),
                        );
                      } else {
                        // Token saved but IDs missing â€” open config dialog pre-filled
                        _showManualConfig(
                          context,
                          wabaId: serverWabaId ?? wabaId,
                          phoneNumberId: serverPhoneId ?? phoneNumberId,
                        );
                      }
                    } else if (mounted) {
                      _showManualConfig(context, wabaId: wabaId, phoneNumberId: phoneNumberId);
                    }
                  } else if (result.status == 'cancelled') {
                    // User cancelled â€” do nothing
                  } else {
                    if (mounted) _showManualConfig(context);
                  }
                } catch (e) {
                  setState(() => _isConnecting = false);
                  if (mounted) _showManualConfig(context);
                }
              },
              icon: _isConnecting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.facebook, size: 24),
              label: Text(
                _isConnecting ? 'Connecting...' : 'Connect Meta Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDetailsCard(BuildContext context, Map<String, dynamic> config) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Meta Account Connected',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildDetailRow('Phone Number ID', config['phoneNumberId'] ?? 'N/A'),
            const Divider(height: 32),
            _buildDetailRow('WABA ID', config['businessAccountId'] ?? 'N/A'),
            const Divider(height: 32),
            _buildDetailRow('Access Token', '••••••••••••••••' + (config['accessToken']?.toString().substring((config['accessToken']?.toString().length ?? 4) - 4) ?? '')),
            const SizedBox(height: 25),
            // OutlinedButton.icon(
            //   onPressed: () => _showManualConfig(context),
            //   icon: const Icon(Icons.edit_note),
            //   label: const Text('Update Connection Settings'),
            //   style: OutlinedButton.styleFrom(
            //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildPlaceholderTile(String title, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        onSuccess: () {
          context.read<AuthBloc>().add(LogoutRequested());
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
          );
        },
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePasswordDialog({required this.onSuccess});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await getIt<WhatsAppRepository>().changePassword(
        currentPassword: _currentCtrl.text.trim(),
        newPassword: _newCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_outline, color: AppTheme.secondaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text('Change Password',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _PasswordField(
                controller: _currentCtrl,
                label: 'Current Password',
                show: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _newCtrl,
                label: 'New Password',
                show: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _confirmCtrl,
                label: 'Confirm New Password',
                show: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: 150,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Update Password',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
