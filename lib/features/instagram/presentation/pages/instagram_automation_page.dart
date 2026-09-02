import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/features/instagram/presentation/pages/instagram_profile_setup_page.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class QuickReplyButton {
  String title;
  String payload;
  String payloadResponse;

  QuickReplyButton({
    required this.title,
    required this.payload,
    this.payloadResponse = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'payload': payload.trim().toUpperCase(),
      };

  factory QuickReplyButton.fromJson(Map<String, dynamic> json) =>
      QuickReplyButton(
        title: json['title']?.toString() ?? '',
        payload: json['payload']?.toString() ?? '',
      );
}

class InstagramAutomation {
  final String id;
  final String name;
  final String triggerType; // 'keyword' | 'any_dm'
  final List<String> triggerKeywords;
  final String replyMessage;
  final List<QuickReplyButton> quickReplies;
  final Map<String, String> payloadResponses;
  final bool isActive;
  final DateTime createdAt;

  InstagramAutomation({
    required this.id,
    required this.name,
    required this.triggerType,
    required this.triggerKeywords,
    required this.replyMessage,
    required this.quickReplies,
    required this.payloadResponses,
    required this.isActive,
    required this.createdAt,
  });

  factory InstagramAutomation.fromJson(Map<String, dynamic> json) {
    final rawQrList = json['quickReplies'] as List? ?? [];
    final qrList = rawQrList.map((e) {
      if (e is Map) {
        return QuickReplyButton.fromJson(Map<String, dynamic>.from(e));
      }
      return QuickReplyButton(title: '', payload: '');
    }).toList();

    final Map<String, String> prMap = {};
    final rawPr = json['payloadResponses'];
    if (rawPr is Map) {
      rawPr.forEach((k, v) => prMap[k.toString()] = v?.toString() ?? '');
    }

    for (final qr in qrList) {
      qr.payloadResponse = prMap[qr.payload] ?? '';
    }

    return InstagramAutomation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Automation',
      triggerType: json['triggerType']?.toString() ?? 'keyword',
      triggerKeywords: (json['triggerKeywords'] as List? ?? [])
          .map((k) => k.toString())
          .toList(),
      replyMessage: json['replyMessage']?.toString() ?? '',
      quickReplies: qrList,
      payloadResponses: prMap,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ── Main Page ────────────────────────────────────────────────────────────────

class InstagramAutomationPage extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;

  const InstagramAutomationPage({
    super.key,
    this.onNavigateToProfile,
  });

  @override
  State<InstagramAutomationPage> createState() =>
      _InstagramAutomationPageState();
}

class _InstagramAutomationPageState extends State<InstagramAutomationPage> {
  final Dio _dio = getIt<Dio>();

  bool _isLoading = true;
  bool _isProfileLoading = true;
  bool _isConnected = false;
  String? _instagramUsername;
  String? _errorMessage;
  List<InstagramAutomation> _automations = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.wait([
      _fetchProfileStatus(),
      _fetchAutomations(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfileStatus() async {
    try {
      final res = await _dio.get('/api/instagram/profile');
      if (mounted && res.data != null) {
        final data = res.data is Map ? res.data as Map : {};
        setState(() {
          _isConnected = data['connected'] == true;
          _instagramUsername = data['username']?.toString();
          _isProfileLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isProfileLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAutomations() async {
    try {
      final res = await _dio.get('/api/instagram/automations');
      if (mounted && res.data != null) {
        final rawList = res.data is List ? res.data as List : [];
        final list = rawList.map((e) {
          if (e is Map) {
            return InstagramAutomation.fromJson(Map<String, dynamic>.from(e));
          }
          return InstagramAutomation.fromJson({});
        }).toList();

        setState(() {
          _automations = list;
          _errorMessage = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['error']?.toString() ??
              'Failed to load automations';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _toggleActive(InstagramAutomation automation) async {
    try {
      await _dio.patch('/api/instagram/automations/${automation.id}/toggle');
      _fetchAutomations();
    } on DioException catch (e) {
      _showSnack(
        e.response?.data?['error']?.toString() ?? 'Failed to toggle status',
        isError: true,
      );
    }
  }

  Future<void> _delete(InstagramAutomation automation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Automation?'),
        content: Text('Are you sure you want to delete "${automation.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 40),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _dio.delete('/api/instagram/automations/${automation.id}');
      _showSnack('Automation deleted successfully');
      _fetchAutomations();
    } on DioException catch (e) {
      _showSnack(
        e.response?.data?['error']?.toString() ?? 'Delete failed',
        isError: true,
      );
    }
  }

  Future<void> _saveAutomation({
    InstagramAutomation? existing,
    required String name,
    required String triggerType,
    required List<String> triggerKeywords,
    required String replyMessage,
    required List<QuickReplyButton> quickReplies,
  }) async {
    final Map<String, String> payloadResponses = {};
    for (final qr in quickReplies) {
      if (qr.payload.trim().isNotEmpty) {
        payloadResponses[qr.payload.trim().toUpperCase()] =
            qr.payloadResponse.trim();
      }
    }

    final body = {
      'name': name.trim(),
      'triggerType': triggerType,
      'triggerKeywords': triggerKeywords,
      'replyMessage': replyMessage.trim(),
      'quickReplies': quickReplies.map((q) => q.toJson()).toList(),
      'payloadResponses': payloadResponses,
    };

    try {
      if (existing == null) {
        await _dio.post('/api/instagram/automations', data: body);
        _showSnack('Automation created successfully');
      } else {
        await _dio.put('/api/instagram/automations/${existing.id}', data: body);
        _showSnack('Automation updated successfully');
      }
      _fetchAutomations();
    } on DioException catch (e) {
      _showSnack(
        e.response?.data?['error']?.toString() ?? 'Save failed',
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _redirectToProfileSetup() {
    if (widget.onNavigateToProfile != null) {
      widget.onNavigateToProfile!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InstagramProfileSetupPage(),
        ),
      );
    }
  }

  void _openDialog({InstagramAutomation? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AutomationDialog(
        existing: existing,
        onSave: (name, triggerType, keywords, replyMsg, quickReplies) =>
            _saveAutomation(
          existing: existing,
          name: name,
          triggerType: triggerType,
          triggerKeywords: keywords,
          replyMessage: replyMsg,
          quickReplies: quickReplies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Bar ─────────────────────────────────────────────────────
          _buildHeaderBar(),
          const SizedBox(height: 24),

          // ── Not Connected Banner (if disconnected) ─────────────────────────
          if (!_isProfileLoading && !_isConnected) ...[
            _buildNotConnectedBanner(),
            const SizedBox(height: 24),
          ],

          // ── Tabs Navigation ────────────────────────────────────────────────
          _buildTabsHeader(),
          const SizedBox(height: 20),

          // ── Quick Replies Tab Content ──────────────────────────────────────
          _buildQuickRepliesTabContent(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB700),
                    Color(0xFFFF007F),
                    Color(0xFF8000FF),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FaIcon(
                FontAwesomeIcons.instagram,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Automate your Instagram',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Set up automated DM flows, keyword triggers, and interactive quick replies for Instagram',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );

    final statusBadge = _buildConnectionStatusBadge();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleColumn,
              const SizedBox(height: 16),
              statusBadge,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 16),
            statusBadge,
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatusBadge() {
    if (_isProfileLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          border: Border.all(color: const Color(0xFFA5D6A7)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _instagramUsername != null && _instagramUsername!.isNotEmpty
                  ? '@$_instagramUsername'
                  : 'Connected',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _redirectToProfileSetup,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          border: Border.all(
            color: const Color(0xFFE1306C).withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.instagram,
              size: 13,
              color: Color(0xFFE1306C),
            ),
            SizedBox(width: 6),
            Text(
              'Not Connected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE1306C),
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 10,
              color: Color(0xFFE1306C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnectedBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber.shade900,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Instagram Account Not Connected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect your Instagram Business account to activate automated quick replies and webhook triggers.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _redirectToProfileSetup,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.amber.shade700),
              foregroundColor: Colors.amber.shade900,
              minimumSize: const Size(175, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text(
              'Go to Profile & Setup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Quick Replies Tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.quickreply_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Replies',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (_automations.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_automations.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isConnected && _automations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ElevatedButton.icon(
                onPressed: () => _openDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'New Automation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickRepliesTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flow info guide card
        _buildFlowInfoCard(),
        const SizedBox(height: 24),

        // Content
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_automations.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _automations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _AutomationCard(
              automation: _automations[i],
              onEdit: () => _openDialog(existing: _automations[i]),
              onDelete: () => _delete(_automations[i]),
              onToggle: () => _toggleActive(_automations[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildFlowInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How Quick Replies Automation Works',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                _flowStep(
                  '1',
                  'User sends an incoming Instagram Direct Message (DM) to your connected account.',
                ),
                _flowStep(
                  '2',
                  'Sendzyy matches keyword (or Any DM) and sends your Reply Text with up to 13 Quick Reply Buttons.',
                ),
                _flowStep(
                  '3',
                  'User clicks a Quick Reply button (e.g. "Pricing", "Demo", "Support") directly inside Instagram DM.',
                ),
                _flowStep(
                  '4',
                  'Sendzyy captures button payload and automatically delivers the configured instant answer.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB700),
                    Color(0xFFFF007F),
                    Color(0xFF8000FF),
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const FaIcon(
                FontAwesomeIcons.instagram,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Quick Reply Automations Yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first interactive flow to automatically reply to Instagram DMs\nwith up to 13 quick reply buttons.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Tooltip(
              message: _isConnected
                  ? 'Create a new automated quick reply flow'
                  : 'Please connect your Instagram account first',
              child: ElevatedButton.icon(
                onPressed: _isConnected ? () => _openDialog() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  minimumSize: const Size(260, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _isConnected ? Icons.add_rounded : Icons.lock_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  _isConnected
                      ? 'Create Quick Reply Automation'
                      : 'Connect Account to Create Automation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!_isConnected) ...[
              const SizedBox(height: 12),
              Text(
                'Please connect your Instagram account above to activate automation features.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade700, size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load data',
              style: TextStyle(color: Colors.red.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 40),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Automation Card ───────────────────────────────────────────────────────────

class _AutomationCard extends StatelessWidget {
  final InstagramAutomation automation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _AutomationCard({
    required this.automation,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: automation.isActive
              ? Colors.green.shade100
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: automation.isActive
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB700),
                        Color(0xFFFF007F),
                        Color(0xFF8000FF),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.instagram,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    automation.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Active toggle switch
                Switch(
                  value: automation.isActive,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: Colors.green.shade600,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                // Active badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: automation.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    automation.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: automation.isActive
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  color: Colors.blue.shade600,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: Colors.red.shade400,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trigger Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.bolt_rounded,
                          size: 15, color: Colors.orange.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Trigger: ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (automation.triggerType == 'any_dm')
                      _chip('Any Incoming DM', Colors.orange)
                    else
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: automation.triggerKeywords
                              .map((k) => _chip(k, Colors.purple))
                              .toList(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reply Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Initial Reply Message',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        automation.replyMessage,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),

                // Quick Reply Buttons List
                if (automation.quickReplies.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Reply Buttons (${automation.quickReplies.length}/13)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: automation.quickReplies.map((qr) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              qr.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if (qr.payloadResponse.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '→ ${qr.payloadResponse}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Create / Edit Dialog ──────────────────────────────────────────────────────

class _AutomationDialog extends StatefulWidget {
  final InstagramAutomation? existing;
  final Future<void> Function(
    String name,
    String triggerType,
    List<String> keywords,
    String replyMessage,
    List<QuickReplyButton> quickReplies,
  ) onSave;

  const _AutomationDialog({this.existing, required this.onSave});

  @override
  State<_AutomationDialog> createState() => _AutomationDialogState();
}

class _AutomationDialogState extends State<_AutomationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _replyCtrl;
  late final TextEditingController _keywordCtrl;

  String _triggerType = 'keyword';
  List<String> _keywords = [];
  List<QuickReplyButton> _quickReplies = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _replyCtrl = TextEditingController(text: e?.replyMessage ?? '');
    _keywordCtrl = TextEditingController();
    _triggerType = e?.triggerType ?? 'keyword';
    _keywords = List<String>.from(e?.triggerKeywords ?? []);
    _quickReplies = e?.quickReplies
            .map((q) => QuickReplyButton(
                  title: q.title,
                  payload: q.payload,
                  payloadResponse: q.payloadResponse,
                ))
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _replyCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _keywordCtrl.text.trim();
    if (kw.isEmpty) return;
    if (_keywords.contains(kw)) {
      _keywordCtrl.clear();
      return;
    }
    setState(() {
      _keywords.add(kw);
      _keywordCtrl.clear();
    });
  }

  void _addQuickReply() {
    if (_quickReplies.length >= 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 13 quick reply buttons allowed per Instagram API specifications.',
          ),
        ),
      );
      return;
    }
    final nextIndex = _quickReplies.length + 1;
    setState(() {
      _quickReplies.add(
        QuickReplyButton(
          title: '',
          payload: 'BUTTON_$nextIndex',
          payloadResponse: '',
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_triggerType == 'keyword' && _keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one trigger keyword'),
        ),
      );
      return;
    }

    for (int i = 0; i < _quickReplies.length; i++) {
      final qr = _quickReplies[i];
      if (qr.title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Button #${i + 1}: Title is required'),
          ),
        );
        return;
      }
      if (qr.title.length > 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Button #${i + 1}: Title cannot exceed 20 characters (Instagram API limitation)',
            ),
          ),
        );
        return;
      }
      if (qr.payload.trim().isEmpty) {
        qr.payload = qr.title.trim().toUpperCase().replaceAll(' ', '_');
      }
    }

    setState(() => _isSaving = true);
    await widget.onSave(
      _nameCtrl.text.trim(),
      _triggerType,
      _keywords,
      _replyCtrl.text.trim(),
      _quickReplies,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFB700),
                          Color(0xFFFF007F),
                          Color(0xFF8000FF),
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit
                        ? 'Edit Quick Reply Flow'
                        : 'New Quick Reply Automation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Automation Name
                      _sectionLabel('Automation Name'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration(
                          'e.g. Welcome & Price Inquiries Flow',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Trigger Type
                      _sectionLabel('Trigger Type'),
                      Row(
                        children: [
                          _triggerTypeChip(
                            'keyword',
                            'Keyword Match',
                            Icons.search_rounded,
                          ),
                          const SizedBox(width: 12),
                          _triggerTypeChip(
                            'any_dm',
                            'Any Incoming DM',
                            Icons.message_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Keywords Section
                      if (_triggerType == 'keyword') ...[
                        _sectionLabel('Trigger Keywords'),
                        Text(
                          'When a user sends any of these words in Instagram DM, this automation triggers.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _keywordCtrl,
                                decoration: _inputDecoration(
                                  'e.g. price, catalogue, demo, hi, info',
                                ),
                                onFieldSubmitted: (_) => _addKeyword(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addKeyword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(80, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                        if (_keywords.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _keywords.map((kw) {
                              return Chip(
                                label: Text(
                                  kw,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                ),
                                onDeleted: () =>
                                    setState(() => _keywords.remove(kw)),
                                backgroundColor: Colors.purple.shade50,
                                side:
                                    BorderSide(color: Colors.purple.shade200),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],

                      // Reply Message
                      _sectionLabel('Initial Reply Message'),
                      Text(
                        'This message is sent immediately along with the Quick Reply buttons below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _replyCtrl,
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: _inputDecoration(
                          'e.g. Thanks for reaching out! 👋 How can we help you today?',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      // Quick Reply Buttons Section
                      Row(
                        children: [
                          Expanded(
                            child: _sectionLabel(
                              'Quick Reply Buttons (${_quickReplies.length}/13)',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addQuickReply,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Button'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Button title max 20 characters per Meta specifications. When tapped, the configured response will be sent automatically.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_quickReplies.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.touch_app_outlined,
                                    color: Colors.grey.shade400, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  'No quick reply buttons added yet.\nClick "+ Add Button" above to attach interactive buttons.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _quickReplies.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _QuickReplyRow(
                            index: i,
                            button: _quickReplies[i],
                            onRemove: () =>
                                setState(() => _quickReplies.removeAt(i)),
                            onChanged: () => setState(() {}),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Create Automation',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _triggerTypeChip(String value, String label, IconData icon) {
    final selected = _triggerType == value;
    return GestureDetector(
      onTap: () => setState(() => _triggerType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Reply Row (inside dialog) ──────────────────────────────────────────

class _QuickReplyRow extends StatefulWidget {
  final int index;
  final QuickReplyButton button;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _QuickReplyRow({
    required this.index,
    required this.button,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_QuickReplyRow> createState() => _QuickReplyRowState();
}

class _QuickReplyRowState extends State<_QuickReplyRow> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _payloadCtrl;
  late final TextEditingController _responseCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.button.title);
    _payloadCtrl = TextEditingController(text: widget.button.payload);
    _responseCtrl = TextEditingController(text: widget.button.payloadResponse);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _payloadCtrl.dispose();
    _responseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Reply Button #${widget.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.red.shade400,
                  size: 18,
                ),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Button Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Button Title (max 20 chars)*',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _titleCtrl,
                      maxLength: 20,
                      onChanged: (v) {
                        widget.button.title = v;
                        if (_payloadCtrl.text.isEmpty ||
                            _payloadCtrl.text.startsWith('BUTTON_')) {
                          final autoPayload =
                              v.trim().toUpperCase().replaceAll(' ', '_');
                          _payloadCtrl.text = autoPayload;
                          widget.button.payload = autoPayload;
                        }
                        widget.onChanged();
                      },
                      decoration: _rowInputDeco('e.g. Pricing, Book Demo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Payload Identifier
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payload (Unique Key)*',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _payloadCtrl,
                      onChanged: (v) {
                        widget.button.payload = v.toUpperCase();
                        widget.onChanged();
                      },
                      decoration: _rowInputDeco('e.g. PRICING, BOOK_DEMO'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bot Response when clicked',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _responseCtrl,
            minLines: 2,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (v) {
              widget.button.payloadResponse = v;
              widget.onChanged();
            },
            decoration: _rowInputDeco(
              'Message to send immediately when user clicks this button...',
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _rowInputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
