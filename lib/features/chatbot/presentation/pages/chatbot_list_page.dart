import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/chatbot_model.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/pages/flow_builder_page.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class ChatbotListPage extends StatefulWidget {
  const ChatbotListPage({super.key});

  @override
  State<ChatbotListPage> createState() => _ChatbotListPageState();
}

class _ChatbotListPageState extends State<ChatbotListPage> {
  // Tracks which chatbot cards have analytics expanded
  final Set<String> _expandedAnalytics = {};

  // Password gate
  bool _isUnlocked = false;
  final Dio _dio = getIt<Dio>();

  @override
  void initState() {
    super.initState();
    // Data is loaded after unlock
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool verifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> verify() async {
            final password = passwordController.text.trim();
            if (password.isEmpty) {
              setDialogState(() => error = 'Please enter your password');
              return;
            }
            setDialogState(() {
              verifying = true;
              error = null;
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              final tenantJson = prefs.getString('tenant_data');
              final email = tenantJson != null
                  ? (jsonDecode(tenantJson) as Map<String, dynamic>)['email']?.toString() ?? ''
                  : '';

              if (email.isEmpty) {
                setDialogState(() {
                  verifying = false;
                  error = 'Could not retrieve account info';
                });
                return;
              }

              final res = await _dio.post('/login', data: {'email': email, 'password': password});
              if (res.statusCode == 200) {
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _isUnlocked = true);
                if (mounted) context.read<ChatbotBloc>().add(LoadChatbots());
              } else {
                setDialogState(() {
                  verifying = false;
                  error = 'Incorrect password';
                });
              }
            } on DioException catch (e) {
              final msg = e.response?.data?['error']?.toString() ?? 'Incorrect password';
              setDialogState(() {
                verifying = false;
                error = msg;
              });
            } catch (_) {
              setDialogState(() {
                verifying = false;
                error = 'Verification failed. Try again.';
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_rounded, color: AppTheme.secondaryColor, size: 22),
                const SizedBox(width: 8),
                const Text('Enter Password'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your login password to access Chatbots.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  enabled: !verifying,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    errorText: error,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) => verify(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: verifying ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: verifying ? null : verify,
                child: verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _navigateToFlowBuilder(ChatbotModel? chatbot) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ChatbotBloc>(),
          child: FlowBuilderPage(chatbot: chatbot),
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<ChatbotBloc>().add(LoadChatbots());
    }
  }

  Future<void> _confirmDelete(BuildContext ctx, ChatbotModel chatbot) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Chatbot'),
        content: Text(
          'Are you sure you want to delete "${chatbot.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<ChatbotBloc>().add(DeleteChatbot(chatbot.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? double.infinity : 450,
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_rounded, size: 40, color: AppTheme.secondaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chatbots',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This section is password protected.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: const Text('Enter Password', style: TextStyle(fontSize: 15)),
                        onPressed: _showPasswordDialog,
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

    return BlocConsumer<ChatbotBloc, ChatbotState>(
      listener: (context, state) {
        if (state is ChatbotLoaded && state.deletedSuccessfully) {
          _showSnackBar('Chatbot deleted');
        }
        if (state is ChatbotError) {
          _showSnackBar(state.message, isError: true);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _navigateToFlowBuilder(null),
            backgroundColor: AppTheme.primaryColor,
            tooltip: 'New Chatbot',
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : (isTablet ? 20 : 32)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chatbots',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _isUnlocked = false),
                      icon: const Icon(Icons.lock, size: 16),
                      label: Text(isMobile ? 'Lock' : 'Lock Section'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your automated WhatsApp chatbot flows',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ChatbotState state) {
    if (state is ChatbotInitial || state is ChatbotLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatbotError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Failed to load chatbots',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(state.message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.read<ChatbotBloc>().add(LoadChatbots()),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      );
    }

    if (state is ChatbotLoaded) {
      if (state.chatbots.isEmpty) {
        return _buildEmptyState(context);
      }
      return _buildChatbotList(context, state.chatbots);
    }

    return const SizedBox();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No chatbots yet',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Automate your WhatsApp conversations with a chatbot flow',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToFlowBuilder(null),
            icon: const Icon(Icons.add),
            label: const Text('Create your first chatbot'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbotList(BuildContext context, List<ChatbotModel> chatbots) {
    return ListView.separated(
      itemCount: chatbots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ChatbotCard(
        chatbot: chatbots[index],
        isAnalyticsExpanded: _expandedAnalytics.contains(chatbots[index].id),
        onEdit: () => _navigateToFlowBuilder(chatbots[index]),
        onDelete: () => _confirmDelete(context, chatbots[index]),
        onToggleActive: (value) {
          context.read<ChatbotBloc>().add(
                ToggleChatbotActive(id: chatbots[index].id, isActive: value),
              );
        },
        onToggleAnalytics: () {
          setState(() {
            final id = chatbots[index].id;
            if (_expandedAnalytics.contains(id)) {
              _expandedAnalytics.remove(id);
            } else {
              _expandedAnalytics.add(id);
              context.read<ChatbotBloc>().add(LoadChatbotAnalytics(chatbots[index].id));
            }
          });
        },
        analyticsState: context.watch<ChatbotBloc>().state,
        chatbotId: chatbots[index].id,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chatbot Card
// ─────────────────────────────────────────────────────────────────────────────

class _ChatbotCard extends StatelessWidget {
  final ChatbotModel chatbot;
  final bool isAnalyticsExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onToggleAnalytics;
  final ChatbotState analyticsState;
  final String chatbotId;

  const _ChatbotCard({
    required this.chatbot,
    required this.isAnalyticsExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleAnalytics,
    required this.analyticsState,
    required this.chatbotId,
  });

  String _formatDate(DateTime dt) {
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(context),
            const SizedBox(height: 12),
            _buildKeywordsRow(),
            const SizedBox(height: 8),
            _buildFooterRow(context),
            const Divider(height: 24),
            _buildAnalyticsRow(context),
            if (isAnalyticsExpanded) ...[
              const SizedBox(height: 12),
              _buildAnalyticsContent(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context) {
    return Row(
      children: [
        // Bot icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primaryColor, size: 22),
        ),
        const SizedBox(width: 12),
        // Name + status badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chatbot.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              _buildStatusBadge(),
            ],
          ),
        ),
        // Edit icon
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: 'Edit',
          onPressed: onEdit,
          color: Colors.grey.shade600,
        ),
        // Delete icon
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Delete',
          onPressed: onDelete,
          color: Colors.redAccent,
        ),
        // Active toggle
        Switch(
          value: chatbot.isActive,
          onChanged: onToggleActive,
          activeThumbColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Chip(
      label: Text(
        chatbot.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chatbot.isActive ? Colors.green.shade700 : Colors.grey.shade600,
        ),
      ),
      backgroundColor: chatbot.isActive
          ? Colors.green.shade50
          : Colors.grey.shade100,
      side: BorderSide(
        color: chatbot.isActive ? Colors.green.shade200 : Colors.grey.shade300,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildKeywordsRow() {
    if (chatbot.triggerKeywords.isEmpty) {
      return Text(
        'No trigger keywords',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chatbot.triggerKeywords.map((kw) {
        return Chip(
          label: Text(kw, style: const TextStyle(fontSize: 12)),
          backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.08),
          side: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.2)),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildFooterRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          'Last modified ${_formatDate(chatbot.updatedAt)}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAnalyticsRow(BuildContext context) {
    return InkWell(
      onTap: onToggleAnalytics,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 16,
              color: AppTheme.accentColor,
            ),
            const SizedBox(width: 6),
            _buildAnalyticsSummaryText(),
            const Spacer(),
            Icon(
              isAnalyticsExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummaryText() {
    if (analyticsState is ChatbotLoaded) {
      final loaded = analyticsState as ChatbotLoaded;
      if (loaded.analyticsLoadedId == chatbotId && loaded.analytics.isNotEmpty) {
        final totalSessions = loaded.analytics.fold<int>(0, (sum, d) => sum + d.totalSessions);
        final completedSessions = loaded.analytics.fold<int>(0, (sum, d) => sum + d.completedSessions);
        final completionRate = totalSessions > 0
            ? ((completedSessions / totalSessions) * 100).round()
            : 0;
        return Text(
          'Sessions: $totalSessions | Completion: $completionRate%',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        );
      }
    }
    return Text(
      'Tap to load analytics',
      style: TextStyle(color: AppTheme.accentColor, fontSize: 13),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context) {
    if (analyticsState is ChatbotLoaded) {
      final loaded = analyticsState as ChatbotLoaded;
      if (loaded.analyticsLoadingId == chatbotId) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (loaded.analyticsLoadedId == chatbotId) {
        if (loaded.analytics.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No analytics data available.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          );
        }
        return _AnalyticsBarChart(analytics: loaded.analytics);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No analytics data available.',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Bar Chart (CustomPaint)
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsBarChart extends StatelessWidget {
  final List<DailyAnalytics> analytics;

  const _AnalyticsBarChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    if (analytics.isEmpty) {
      return Text(
        'No data for the last 7 days.',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '7-Day Trend',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: _BarChartPainter(analytics: analytics),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppTheme.primaryColor, label: 'Started'),
            const SizedBox(width: 16),
            _LegendDot(color: AppTheme.accentColor, label: 'Completed'),
          ],
        ),
      ],
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
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyAnalytics> analytics;

  _BarChartPainter({required this.analytics});

  @override
  void paint(Canvas canvas, Size size) {
    if (analytics.isEmpty) return;

    final maxVal = analytics
        .map((d) => math.max(d.totalSessions, d.completedSessions))
        .reduce(math.max)
        .toDouble();

    if (maxVal == 0) {
      // Draw empty state text
      final tp = TextPainter(
        text: const TextSpan(
          text: 'No sessions recorded',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      return;
    }

    final barGroupWidth = size.width / analytics.length;
    final barWidth = barGroupWidth * 0.3;
    final chartHeight = size.height - 20; // leave room for date labels

    final startedPaint = Paint()..color = AppTheme.primaryColor;
    final completedPaint = Paint()..color = AppTheme.accentColor;
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    // Draw baseline
    canvas.drawLine(Offset(0, chartHeight), Offset(size.width, chartHeight), axisPaint);

    for (int i = 0; i < analytics.length; i++) {
      final d = analytics[i];
      final groupX = barGroupWidth * i + barGroupWidth / 2;

      // Started bar
      final startedHeight = (d.totalSessions / maxVal) * chartHeight;
      final startedRect = Rect.fromLTWH(
        groupX - barWidth - 2,
        chartHeight - startedHeight,
        barWidth,
        startedHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(startedRect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        startedPaint,
      );

      // Completed bar
      final completedHeight = (d.completedSessions / maxVal) * chartHeight;
      final completedRect = Rect.fromLTWH(
        groupX + 2,
        chartHeight - completedHeight,
        barWidth,
        completedHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(completedRect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        completedPaint,
      );

      // Date label
      final label = DateFormat('M/d').format(d.date);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(groupX - tp.width / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) => oldDelegate.analytics != analytics;
}
