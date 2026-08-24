import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/login_page.dart';

import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/messages/presentation/pages/bulk_send_page.dart';
import 'package:iFloraBuzz/features/templates/presentation/pages/template_list_page.dart';
import 'package:iFloraBuzz/features/reports/presentation/pages/reports_page.dart';
import 'package:iFloraBuzz/features/reports/presentation/pages/meta_analytics_page.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/package_selection_page.dart';
import 'package:iFloraBuzz/features/chat/presentation/pages/chat_page.dart';
import 'package:iFloraBuzz/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:iFloraBuzz/features/clients/presentation/pages/clients_page.dart';
import 'package:iFloraBuzz/features/settings/presentation/pages/settings_page.dart';
import 'package:iFloraBuzz/features/help/presentation/pages/help_page.dart';
import 'package:iFloraBuzz/features/scheduled/presentation/pages/scheduled_campaigns_page.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/pages/chatbot_list_page.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/pages/catalog_page.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/leads/presentation/pages/lead_management_page.dart';
import 'package:iFloraBuzz/features/integrations/presentation/pages/integration_settings_page.dart';
import 'package:iFloraBuzz/features/retry/presentation/pages/retry_system_page.dart';
import 'package:iFloraBuzz/features/calling/presentation/pages/call_log_page.dart';
import 'package:iFloraBuzz/features/calling/presentation/pages/calling_settings_page.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/services/renewal_reminder_service.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/core/widgets/password_verification_dialog.dart';
import 'package:flutter/services.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:iFloraBuzz/features/notifications/data/datasources/fcm_service.dart';
import 'package:iFloraBuzz/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:iFloraBuzz/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/whatsapp_business_profile_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime;
  int _selectedIndex = 0;
  bool _isReportsExpanded = false;
  bool _isSettingsExpanded = false;
  late final RenewalReminderService _reminderService;
  bool _onboardingIncomplete = false;
  bool _checkingOnboarding = true;

  String? _metaProfileImageUrl;
  String? _lastFetchedPhoneId;

  List<Map<String, dynamic>> _headerPhoneNumbers = [];
  bool _loadingHeaderPhoneNumbers = false;
  String? _headerWabaId;
  bool _isHeaderUpdatingPhone = false;

  static const _selectedIndexKey = 'dashboard_selected_index';

  @override
  void initState() {
    super.initState();
    _restoreSelectedIndex();
    _initReminderService();
    _checkOnboardingStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFcm();
    });
  }

  void _initFcm() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final tenantId = authState.tenant['id']?.toString() ??
            authState.tenant['_id']?.toString() ??
            '';
        if (tenantId.isNotEmpty) {
          FCMService.initialize(
            tenantId: tenantId,
            remoteDataSource: getIt<NotificationRemoteDataSource>(),
          );
        }
      }
    } catch (e) {
      debugPrint('[FCM] Shell init warning: $e');
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final dio = getIt<Dio>();
      final resp = await dio.get('/onboarding-status');
      final data = resp.data;
      final connected = data['whatsappConnected'] ?? false;
      final phone = data['phoneVerified'] ?? false;
      final bizVerified = data['metaBusinessVerified'] == 'VERIFIED';
      final template = data['hasApprovedTemplate'] ?? false;

      if (mounted) {
        setState(() {
          _onboardingIncomplete =
              !(connected && phone && bizVerified && template);
          _checkingOnboarding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
        });
      }
    }
  }

  Future<void> _fetchMetaProfileIfNeeded(Map<String, dynamic>? config) async {
    if (config == null) return;
    final phoneId = config['phoneNumberId']?.toString();
    final token = config['accessToken']?.toString();

    if (phoneId == null || token == null || phoneId.isEmpty || token.isEmpty) {
      return;
    }

    if (phoneId == _lastFetchedPhoneId) {
      return;
    }

    _lastFetchedPhoneId = phoneId;

    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConstants.metaGraphUrl}/$phoneId/whatsapp_business_profile',
        queryParameters: {
          'fields':
              'about,address,description,email,profile_picture_url,websites,vertical',
          'access_token': token,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        if (data.isNotEmpty) {
          final profile = data.first;
          if (mounted) {
            setState(() {
              _metaProfileImageUrl = profile['profile_picture_url']?.toString();
            });
          }
        }
      }
    } catch (_) {
      // Fail silently, fallback to defaults
    }
  }

  Future<void> _restoreSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_selectedIndexKey) ?? 0;
    if (mounted) {
      setState(() {
        _selectedIndex = saved;
        if (saved >= 5 && saved <= 7) {
          _isReportsExpanded = true;
        }
        if (saved >= 10 && saved <= 12) {
          _isSettingsExpanded = true;
        }
      });
    }
  }

  Future<void> _setSelectedIndex(int index, {bool closeDrawer = false}) async {
    if (closeDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
    }
    setState(() {
      _selectedIndex = index;
      if (index >= 5 && index <= 7) {
        _isReportsExpanded = true;
      }
      if (index >= 10 && index <= 12) {
        _isSettingsExpanded = true;
      }
    });
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
                child: Icon(
                  Icons.logout_rounded,
                  size: 36,
                  color: Colors.red.shade500,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Logging out?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You\'re signed in as $name.\nAre you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
              final subscription =
                  authState.tenant['subscription'] as Map<String, dynamic>?;
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PackageSelectionPage()),
            );
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
    const MetaAnalyticsPage(),
    const ScheduledCampaignsPage(),
    const ChatbotListPage(),
    const HelpPage(),
    SettingsPage(
      onRenewPlan: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PackageSelectionPage()),
      ),
    ),
    const IntegrationSettingsPage(),
    const RetrySystemPage(),
    const CallLogPage(),
    const CallingSettingsPage(phoneNumberId: ''),
    const CatalogPage(),
  ];

  Widget _buildSidebarContent({bool isDrawer = false}) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: Image.asset('assets/images/logo.png')),
              if (isDrawer)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildNavItem(0, Icons.send_rounded, 'Broadcast', isDrawer: isDrawer),
                _buildNavItem(1, Icons.forum_rounded, 'Chats', isDrawer: isDrawer),
                _buildNavItem(2, Icons.copy_rounded, 'Templates', isDrawer: isDrawer),
                _buildNavItem(3, Icons.people_alt_rounded, 'Clients', isDrawer: isDrawer),
                _buildNavItem(4, Icons.contacts_rounded, 'Leads', isDrawer: isDrawer),
                _buildExpandableReportsMenu(isDrawer: isDrawer),
                _buildNavItem(8, Icons.smart_toy_rounded, 'Chatbot', isDrawer: isDrawer),
                // TODO: Work on this module later
                // _buildNavItem(15, Icons.storefront_rounded, 'Catalog', isDrawer: isDrawer),
                // _buildNavItem(13, Icons.call_rounded, 'Call Logs', isDrawer: isDrawer),
                _buildNavItem(9, Icons.help_outline_rounded, 'Q & A', isDrawer: isDrawer),
                const SizedBox(height: 16),
                const Divider(
                  color: AppTheme.secondaryColor,
                  indent: 20,
                  endIndent: 20,
                ),
                _buildExpandableSettingsMenu(isDrawer: isDrawer),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
          return;
        }
        if (_selectedIndex != 0) {
          _setSelectedIndex(0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit app'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => getIt<ChatBloc>()),
          BlocProvider(create: (context) => getIt<ChatbotBloc>()),
          BlocProvider(create: (context) => getIt<CatalogBloc>()),
        ],
        child: Scaffold(
          key: _scaffoldKey,
          drawer: (isMobile || isTablet)
              ? Drawer(
                  backgroundColor: Colors.white,
                  child: SafeArea(child: _buildSidebarContent(isDrawer: true)),
                )
              : null,
          bottomNavigationBar: isMobile
              ? BottomNavigationBar(
                  currentIndex: _selectedIndex > 4 ? 4 : _selectedIndex,
                  onTap: (index) {
                    if (index == 4) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      _setSelectedIndex(index);
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppTheme.primaryColor,
                  unselectedItemColor: Colors.grey.shade600,
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.send_rounded),
                      label: 'Broadcast',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.forum_rounded),
                      label: 'Chats',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.copy_rounded),
                      label: 'Templates',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.people_alt_rounded),
                      label: 'Clients',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.menu_rounded),
                      label: 'More',
                    ),
                  ],
                )
              : null,
          body: Row(
            children: [
              // Desktop Sidebar
              if (!isMobile && !isTablet) ...[
                Container(
                  width: 260,
                  color: Colors.white,
                  child: _buildSidebarContent(isDrawer: false),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE0E0E0),
                ),
              ],
              // Main Content
              Expanded(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),
                      if (!_checkingOnboarding && _onboardingIncomplete)
                        _buildOnboardingWarningBanner(),
                      // Page Content
                      Expanded(child: _pages[_selectedIndex]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSettingsMenu({bool isDrawer = false}) {
    final bool isAnySettingsSelected =
        (_selectedIndex >= 10 && _selectedIndex <= 12) || _selectedIndex == 14;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isSettingsExpanded = !_isSettingsExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isAnySettingsSelected && !_isSettingsExpanded
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.settings_rounded,
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: isAnySettingsSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isSettingsExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                _buildNavItem(
                  10,
                  Icons.tune_rounded,
                  'General Settings',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
                _buildNavItem(
                  11,
                  Icons.integration_instructions_rounded,
                  'Integrations',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
                _buildNavItem(
                  12,
                  Icons.replay_circle_filled_outlined,
                  'Retry System',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
                // TODO: Work on this module later
                // _buildNavItem(
                //   14,
                //   Icons.phone_in_talk_rounded,
                //   'Call Settings',
                //   isSubItem: true,
                //   isDrawer: isDrawer,
                // ),
              ],
            ),
          ),
          crossFadeState: _isSettingsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildExpandableReportsMenu({bool isDrawer = false}) {
    final bool isAnyReportSelected = _selectedIndex >= 5 && _selectedIndex <= 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isReportsExpanded = !_isReportsExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isAnyReportSelected && !_isReportsExpanded
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Reports',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: isAnyReportSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isReportsExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                _buildNavItem(
                  5,
                  Icons.analytics_outlined,
                  'Campaign Reports',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
                _buildNavItem(
                  6,
                  Icons.insights_rounded,
                  'Meta Analytics',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
                _buildNavItem(
                  7,
                  Icons.schedule_rounded,
                  'Scheduled',
                  isSubItem: true,
                  isDrawer: isDrawer,
                ),
              ],
            ),
          ),
          crossFadeState: _isReportsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool isSubItem = false,
    bool isDrawer = false,
  }) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _setSelectedIndex(index, closeDrawer: isDrawer),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(
          left: isSubItem ? 12 : 12,
          right: 12,
          top: 3,
          bottom: 3,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSubItem ? 14 : 16,
          vertical: isSubItem ? 10 : 12,
        ),
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
              size: isSubItem ? 19 : 22,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.secondaryColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: isSubItem ? 13.5 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchHeaderPhoneNumbers(
    String wabaId,
    String accessToken,
  ) async {
    if (_loadingHeaderPhoneNumbers) return;
    setState(() {
      _loadingHeaderPhoneNumbers = true;
      _headerWabaId = wabaId;
    });
    try {
      final numbers = await getIt<WhatsAppRepository>().fetchPhoneNumbers(
        wabaId: wabaId,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          _headerPhoneNumbers = numbers ?? [];
          _loadingHeaderPhoneNumbers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingHeaderPhoneNumbers = false;
        });
      }
    }
  }

  Future<void> _updateHeaderActivePhoneNumber(
    Map<String, dynamic> phone,
    Map<String, dynamic> config,
  ) async {
    setState(() {
      _isHeaderUpdatingPhone = true;
    });
    try {
      final success = await getIt<WhatsAppRepository>().updateConfig(
        phoneNumberId: phone['id']?.toString() ?? '',
        accessToken: config['accessToken']?.toString() ?? '',
        businessAccountId: config['businessAccountId']?.toString() ?? '',
        metaAppId: config['metaAppId']?.toString() ?? '',
        displayPhone: phone['display_phone_number']?.toString(),
        verifiedName: phone['verified_name']?.toString(),
        qualityRating: phone['quality_rating']?.toString(),
        throughputLevel: phone['throughput']?['level']?.toString(),
      );

      if (success) {
        if (mounted) {
          context.read<AuthBloc>().add(AuthCheckRequested());
          context.read<TemplateBloc>().add(FetchTemplates());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Active phone number updated successfully!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update active phone number'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating active phone number: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHeaderUpdatingPhone = false;
        });
      }
    }
  }

  Widget _buildHeaderBadgeWidget(String value) {
    Color badgeColor;
    switch (value.toUpperCase()) {
      case 'GREEN':
        badgeColor = Colors.green;
        break;
      case 'YELLOW':
        badgeColor = Colors.orange;
        break;
      case 'RED':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildHeaderPhoneSelector(Map<String, dynamic> config) {
    final wabaId = config['businessAccountId']?.toString();
    final accessToken = config['accessToken']?.toString();
    final currentPhoneId = config['phoneNumberId']?.toString();

    if (wabaId != null &&
        accessToken != null &&
        wabaId != _headerWabaId &&
        !_loadingHeaderPhoneNumbers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchHeaderPhoneNumbers(wabaId, accessToken);
      });
    }

    if (currentPhoneId == null || currentPhoneId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isHeaderUpdatingPhone || _loadingHeaderPhoneNumbers) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.secondaryColor,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Updating...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> itemsList = List.from(_headerPhoneNumbers);
    final hasCurrent = itemsList.any(
      (p) => p['id']?.toString() == currentPhoneId,
    );
    if (!hasCurrent) {
      itemsList.insert(0, {
        'id': currentPhoneId,
        'display_phone_number': config['displayPhone'] ?? 'Active Number',
        'verified_name': config['verifiedName'] ?? 'Verified Name',
        'quality_rating': config['qualityRating'] ?? 'GREEN',
      });
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentPhoneId,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppTheme.secondaryColor,
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          onChanged: (selectedId) async {
            if (selectedId != null && selectedId != currentPhoneId) {
              final verified = await showPasswordVerificationDialog(
                context,
                prompt:
                    'Enter your login password to change WhatsApp phone number.',
              );
              if (verified) {
                final selectedPhone = itemsList.firstWhere(
                  (p) => p['id']?.toString() == selectedId,
                );
                _updateHeaderActivePhoneNumber(selectedPhone, config);
              } else {
                if (mounted) setState(() {});
              }
            }
          },
          items: itemsList.map((phone) {
            final id = phone['id']?.toString() ?? '';
            final displayPhone =
                phone['display_phone_number']?.toString() ?? 'Unknown';
            final verifiedName = phone['verified_name']?.toString() ?? '';
            final rating = phone['quality_rating']?.toString() ?? 'GREEN';

            return DropdownMenuItem<String>(
              value: id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    id == currentPhoneId
                        ? Icons.check_circle
                        : Icons.phone_android_rounded,
                    color: id == currentPhoneId ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (verifiedName.isNotEmpty)
                        Text(
                          verifiedName,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderBadgeWidget(rating),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      height: isMobile ? 64 : 80,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          if (isMobile || isTablet) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppTheme.secondaryColor),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
          // Panel expiry badge (Desktop & Tablet only)
          if (!isMobile)
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }

                final subscription =
                    authState.tenant['subscription'] as Map<String, dynamic>?;
                final expiryDateStr = subscription?['expiryDate'];
                if (expiryDateStr == null) {
                  return const SizedBox.shrink();
                }

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 6),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Phone Selector Dropdown (Desktop & Tablet only)
                  if (!isMobile) ...[
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is AuthAuthenticated) {
                          final config =
                              authState.tenant['whatsappConfig'] as Map<String, dynamic>?;
                          if (config != null &&
                              config['accessToken'] != null &&
                              config['accessToken'].toString().isNotEmpty) {
                            return _buildHeaderPhoneSelector(config);
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Notification Bell Icon with Badge Count
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      if (authState is AuthAuthenticated) {
                        final tenantId = authState.tenant['id']?.toString() ??
                            authState.tenant['_id']?.toString() ??
                            '';
                        if (tenantId.isNotEmpty) {
                          return NotificationBellIcon(tenantId: tenantId);
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(width: 4),

                  // Support button
                  _SupportButton(),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    const VerticalDivider(indent: 20, endIndent: 20),
                    const SizedBox(width: 12),
                  ] else ...[
                    const SizedBox(width: 4),
                  ],
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      String name = 'User';
                      if (state is AuthAuthenticated) {
                        final config = state.tenant['whatsappConfig'];
                        if (config != null &&
                            config['verifiedName'] != null &&
                            config['verifiedName'].toString().isNotEmpty) {
                          name = config['verifiedName'].toString();
                        } else {
                          name = state.user;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _fetchMetaProfileIfNeeded(config);
                        });
                      }
                      final displayName = name;
                      final firstLetter = displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'U';

                      return PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'whatsapp_profile') {
                            if (state is AuthAuthenticated) {
                              final config =
                                  state.tenant['whatsappConfig']
                                      as Map<String, dynamic>? ??
                                  {};
                              WhatsAppBusinessProfileDialog.show(context, config);
                            }
                          } else if (val == 'logout') {
                            _showLogoutDialog(context, name);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        offset: const Offset(0, 56),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            enabled: false,
                            padding: EdgeInsets.zero,
                            child: Container(
                              width: 240,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withValues(alpha: 0.06),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.secondaryColor,
                                    backgroundImage: _metaProfileImageUrl != null
                                        ? NetworkImage(_metaProfileImageUrl!)
                                        : null,
                                    child: _metaProfileImageUrl == null
                                        ? Text(
                                            firstLetter,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          'Tenant Account',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          PopupMenuItem<String>(
                            value: 'whatsapp_profile',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'WhatsApp Business Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          PopupMenuItem<String>(
                            value: 'logout',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    size: 16,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: isMobile
                            ? CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.secondaryColor,
                                backgroundImage: _metaProfileImageUrl != null
                                    ? NetworkImage(_metaProfileImageUrl!)
                                    : null,
                                child: _metaProfileImageUrl == null
                                    ? Text(
                                        firstLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      )
                                    : null,
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.secondaryColor,
                                    backgroundImage: _metaProfileImageUrl != null
                                        ? NetworkImage(_metaProfileImageUrl!)
                                        : null,
                                    child: _metaProfileImageUrl == null
                                        ? Text(
                                            firstLetter,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    displayName.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down),
                                ],
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingWarningBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your WhatsApp Onboarding is incomplete. Complete it to avoid message limits and start campaigns.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {
              _setSelectedIndex(9);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Complete Setup',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
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
                          child: const Icon(
                            Icons.headset_mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
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
            border: Border.all(
              color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.headset_mic_rounded,
                size: 17,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 6),
              const Text(
                'Support',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryColor,
                ),
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

  const _SupportItem({
    required this.icon,
    required this.label,
    required this.value,
  });

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
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
