import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/login_page.dart';
import 'package:iFloraBuzz/features/auth/presentation/widgets/api_config_dialog.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/messages/presentation/pages/bulk_send_page.dart';
import 'package:iFloraBuzz/features/templates/presentation/pages/template_list_page.dart';
import 'package:iFloraBuzz/features/reports/presentation/pages/reports_page.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/package_selection_page.dart';
import 'package:iFloraBuzz/features/chat/presentation/pages/chat_page.dart';
import 'package:iFloraBuzz/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/pages/clients_page.dart';
import 'package:iFloraBuzz/features/settings/presentation/pages/settings_page.dart';
import 'package:iFloraBuzz/features/help/presentation/pages/help_page.dart';
import 'package:iFloraBuzz/features/scheduled/presentation/pages/scheduled_campaigns_page.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/pages/chatbot_list_page.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/leads/presentation/pages/lead_management_page.dart';
import 'package:iFloraBuzz/features/integrations/presentation/pages/integration_settings_page.dart';
import 'package:iFloraBuzz/features/retry/presentation/pages/retry_system_page.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/services/renewal_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;
  late final RenewalReminderService _reminderService;

  static const _selectedIndexKey = 'dashboard_selected_index';

  @override
  void initState() {
    super.initState();
    _restoreSelectedIndex();
    _initReminderService();
  }

  Future<void> _restoreSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_selectedIndexKey) ?? 0;
    if (mounted) setState(() => _selectedIndex = saved);
  }

  Future<void> _setSelectedIndex(int index) async {
    setState(() => _selectedIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedIndexKey, index);
  }

  void _showLogoutDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded, size: 36, color: Colors.red.shade500),
              ),
              const SizedBox(height: 20),
              const Text('Logging out?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              Text(
                'You\'re signed in as $name.\nAre you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<AuthBloc>().add(LogoutRequested());
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initReminderService() async {
    final prefs = await SharedPreferences.getInstance();
    _reminderService = RenewalReminderService(prefs);

    // Delay first check until after the first frame so BLoC is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reminderService.start(
        getExpiryDate: () {
          if (!mounted) return null;
          try {
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final subscription = authState.tenant['subscription'] as Map<String, dynamic>?;
              final expiryDate = subscription?['expiryDate'];
              if (expiryDate is String) {
                return DateTime.parse(expiryDate);
              }
            }
            return null;
          } catch (_) {
            return null;
          }
        },
        onShow: (expiresAt, daysLeft) async {
          await _reminderService.markShown();
          if (!mounted) return;
          final goToRenew = await RenewalReminderService.showReminderDialog(
            context,
            expiresAt: expiresAt,
            daysLeft: daysLeft,
          );
          if (goToRenew && mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageSelectionPage()));
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _reminderService.stop();
    super.dispose();
  }

  List<Widget> get _pages => [
    const BulkSendPage(),
    const ChatPage(),
    const TemplateListPage(),
    const ClientsPage(),
    const LeadManagementPage(),
    const ReportsPage(),
    const ScheduledCampaignsPage(),
    const ChatbotListPage(),
    const HelpPage(),
    SettingsPage(onRenewPlan: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageSelectionPage()))),
    const IntegrationSettingsPage(),
    const RetrySystemPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => getIt<ChatBloc>(),
        ),
        BlocProvider(
          create: (context) => getIt<ChatbotBloc>(),
        ),
      ],
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 260,
                color: Colors.white,
              child: Column(
                children: [
                                   const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildNavItem(0, Icons.send_rounded, 'Bulk Send'),
                          _buildNavItem(1, Icons.forum_rounded, 'Chats'),
                          _buildNavItem(2, Icons.copy_rounded, 'Templates'),
                          _buildNavItem(3, Icons.people_alt_rounded, 'Clients'),
                          _buildNavItem(4, Icons.contacts_rounded, 'Leads'),
                          _buildNavItem(5, Icons.bar_chart_rounded, 'Reports'),
                          _buildNavItem(6, Icons.schedule_rounded, 'Scheduled'),
                          _buildNavItem(7, Icons.smart_toy_rounded, 'Chatbot'),
                          _buildNavItem(8, Icons.help_outline_rounded, 'Q & A'),
                          const SizedBox(height: 16),
                          const Divider(
                            color: AppTheme.secondaryColor,
                            indent: 20,
                            endIndent: 20,
                          ),
                          _buildNavItem(9, Icons.settings_rounded, 'Settings'),
                          _buildNavItem(10, Icons.integration_instructions_rounded, 'Integrations'),
                          _buildNavItem(11, Icons.replay_circle_filled_outlined, 'Retry System'),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
             const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            // Main Content
            Expanded(
              child: Container(
                color: AppTheme.backgroundColor,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),
                    // Page Content
                    Expanded(child: _pages[_selectedIndex]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _setSelectedIndex(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.secondaryColor
                  : AppTheme.secondaryColor,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                  ? AppTheme.secondaryColor
                  : AppTheme.secondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Panel expiry badge
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is! AuthAuthenticated) return const SizedBox.shrink();
              
              final subscription = authState.tenant['subscription'] as Map<String, dynamic>?;
              final expiryDateStr = subscription?['expiryDate'];
              if (expiryDateStr == null) return const SizedBox.shrink();
              
              final exp = DateTime.parse(expiryDateStr as String);
              final daysLeft = exp.difference(DateTime.now()).inDays;
              final isExpired = daysLeft < 0;
              final isWarning = daysLeft <= 7 && !isExpired;
              final color = isExpired
                  ? Colors.red
                  : isWarning
                      ? Colors.orange
                      : AppTheme.secondaryColor;
              final expStr =
                  '${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year}';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today_outlined,
                      size: 15,
                      color: color,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isExpired
                          ? 'Dashboard Expired'
                          : 'Dashboard Exp on $expStr',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (!isExpired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$daysLeft d',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              // Show settings gear only when phoneNumberId or businessAccountId is missing
              final bool configIncomplete = () {
                if (authState is AuthAuthenticated) {
                  final config = authState.tenant['whatsappConfig'] as Map<String, dynamic>?;
                  final phoneId = config?['phoneNumberId']?.toString() ?? '';
                  final wabaId = config?['businessAccountId']?.toString() ?? '';
                  return phoneId.isEmpty || wabaId.isEmpty;
                }
                return false;
              }();

              if (!configIncomplete) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.grey),
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) => const ApiConfigDialog(),
                  );
                  if (result == true && context.mounted) {
                    context.read<AuthBloc>().add(AuthCheckRequested());
                    context.read<TemplateBloc>().add(FetchTemplates());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API Configuration Updated')),
                    );
                  }
                },
                tooltip: 'API Configuration',
              );
            },
          ),
          const SizedBox(width: 8),
          // Support button
          _SupportButton(),
          const SizedBox(width: 8),
          const VerticalDivider(indent: 20, endIndent: 20),
          const SizedBox(width: 24),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String name = 'User';
              if (state is AuthAuthenticated) {
                name = state.user;
              }
              return PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'logout') {
                    _showLogoutDialog(context, name);
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                offset: const Offset(0, 56),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    padding: EdgeInsets.zero,
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.secondaryColor,
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
                                const Text('Tenant Account', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'logout',
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout_rounded, size: 16, color: Colors.red.shade600),
                        ),
                        const SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.secondaryColor,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support Button + Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SupportButton extends StatelessWidget {
  const _SupportButton();

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                decoration: const BoxDecoration(color: AppTheme.secondaryColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Still need help?',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Contact Us',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Contact items
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const _SupportItem(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: 'iflorainfopvtltd@gmail.com',
                    ),
                    const SizedBox(height: 16),
                    const _SupportItem(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: '+91 90997 05065',
                    ),
                    const SizedBox(height: 16),
                    const _SupportItem(
                      icon: Icons.language_outlined,
                      label: 'Website',
                      value: 'www.iflorainfo.com',
                    ),
                    const SizedBox(height: 16),
                    const _SupportItem(
                      icon: Icons.access_time_rounded,
                      label: 'Support Hours',
                      value: 'Mon – Sat, 9:00 AM – 6:00 PM IST',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Support',
      child: InkWell(
        onTap: () => _showSupportDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headset_mic_rounded, size: 17, color: AppTheme.secondaryColor),
              const SizedBox(width: 6),
              const Text(
                'Support',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SupportItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.secondaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
