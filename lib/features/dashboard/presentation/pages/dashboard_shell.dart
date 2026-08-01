import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sendzyy/features/auth/presentation/pages/login_page.dart';

import 'package:dio/dio.dart';
import 'package:sendzyy/features/templates/presentation/bloc/template_bloc.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/messages/presentation/pages/bulk_send_page.dart';
import 'package:sendzyy/features/templates/presentation/pages/template_list_page.dart';
import 'package:sendzyy/features/reports/presentation/pages/reports_page.dart';
import 'package:sendzyy/features/reports/presentation/pages/meta_analytics_page.dart';
import 'package:sendzyy/features/auth/presentation/pages/package_selection_page.dart';
import 'package:sendzyy/features/chat/presentation/pages/chat_page.dart';
import 'package:sendzyy/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:sendzyy/features/clients/presentation/pages/clients_page.dart';
import 'package:sendzyy/features/settings/presentation/pages/settings_page.dart';
import 'package:sendzyy/features/help/presentation/pages/help_page.dart';
import 'package:sendzyy/features/scheduled/presentation/pages/scheduled_campaigns_page.dart';
import 'package:sendzyy/features/chatbot/presentation/pages/chatbot_list_page.dart';
import 'package:sendzyy/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:sendzyy/features/leads/presentation/pages/lead_management_page.dart';
import 'package:sendzyy/features/integrations/presentation/pages/integration_settings_page.dart';
import 'package:sendzyy/features/retry/presentation/pages/retry_system_page.dart';
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/core/services/renewal_reminder_service.dart';
import 'package:sendzyy/core/constants/app_constants.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:sendzyy/core/widgets/password_verification_dialog.dart';
import 'package:sendzyy/features/settings/presentation/widgets/whatsapp_business_profile_dialog.dart';
import 'package:sendzyy/features/notifications/presentation/widgets/notification_bell_icon.dart';
import 'package:sendzyy/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;
  bool _isReportsExpanded = false;
  bool _isSettingsExpanded = false;
  late final RenewalReminderService _reminderService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _onboardingIncomplete = false;
  bool _checkingOnboarding = true;

  String? _metaProfileImageUrl;
  String? _lastFetchedPhoneId;

  List<Map<String, dynamic>> _headerPhoneNumbers = [];
  bool _loadingHeaderPhoneNumbers = false;
  String? _headerWabaId;
  bool _fetchedHeaderPhoneNumbers = false; // true once fetch has been attempted for _headerWabaId
  bool _isHeaderUpdatingPhone = false;

  static const _selectedIndexKey = 'dashboard_selected_index';

  @override
  void initState() {
    super.initState();
    _restoreSelectedIndex();
    _initReminderService();
    _checkOnboardingStatus();
    _loadCachedPhoneNumbers();
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

  Future<void> _setSelectedIndex(int index) async {
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
  ];

  Widget _buildSidebar(bool isMobile) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 48,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(0, Icons.send_rounded, 'Broadcast', isMobile: isMobile),
                  _buildNavItem(1, Icons.forum_rounded, 'Chats', isMobile: isMobile),
                  _buildNavItem(2, Icons.copy_rounded, 'Templates', isMobile: isMobile),
                  _buildNavItem(3, Icons.people_alt_rounded, 'Clients', isMobile: isMobile),
                  _buildNavItem(4, Icons.contacts_rounded, 'Leads', isMobile: isMobile),
                  _buildExpandableReportsMenu(isMobile: isMobile),
                  _buildNavItem(8, Icons.smart_toy_rounded, 'Chatbot', isMobile: isMobile),
                  _buildNavItem(9, Icons.help_outline_rounded, 'Q & A', isMobile: isMobile),
                  const SizedBox(height: 16),
                  const Divider(
                    color: AppTheme.secondaryColor,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildExpandableSettingsMenu(isMobile: isMobile),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<ChatBloc>()),
        BlocProvider(create: (context) => getIt<ChatbotBloc>()),
      ],
      child: Builder(
        builder: (scaffoldContext) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: isMobile ? Drawer(child: SafeArea(child: _buildSidebar(true))) : null,
            bottomNavigationBar: isMobile ? _buildBottomNavigationBar() : null,
            body: Row(
              children: [
                // Sidebar for desktop
                if (!isMobile) ...[
                  _buildSidebar(false),
                  const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                ],
                // Main Content
                Expanded(
                  child: Container(
                    color: AppTheme.backgroundColor,
                    child: SafeArea(
                      top: true,
                      bottom: false,
                      child: Column(
                        children: [
                          // Header
                          _buildHeader(isMobile),
                          if (!_checkingOnboarding && _onboardingIncomplete)
                            _buildOnboardingWarningBanner(),
                          // Page Content
                          Expanded(
                            child: (isMobile && _selectedIndex == 6)
                                ? _pages[5]
                                : _pages[_selectedIndex],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    int activeBottomIndex = 0;
    if (_selectedIndex == 1) {
      activeBottomIndex = 0;
    } else if (_selectedIndex == 0) {
      activeBottomIndex = 1;
    } else if (_selectedIndex == 2) {
      activeBottomIndex = 2;
    } else if (_selectedIndex == 3) {
      activeBottomIndex = 3;
    } else {
      activeBottomIndex = 4;
    }

    final items = [
      (icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chats'),
      (icon: Icons.send_outlined, activeIcon: Icons.send_rounded, label: 'Broadcast'),
      (icon: Icons.copy_outlined, activeIcon: Icons.copy_rounded, label: 'Templates'),
      (icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Clients'),
      (icon: Icons.menu_rounded, activeIcon: Icons.menu_rounded, label: 'More'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = activeBottomIndex == index;
              final item = items[index];
              return InkWell(
                onTap: () {
                  if (index == 0) {
                    _setSelectedIndex(1);
                  } else if (index == 1) {
                    _setSelectedIndex(0);
                  } else if (index == 2) {
                    _setSelectedIndex(2);
                  } else if (index == 3) {
                    _setSelectedIndex(3);
                  } else if (index == 4) {
                    _scaffoldKey.currentState?.openDrawer();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        size: 21,
                        color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade600,
                        ),
                      ), 
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSettingsMenu({bool isMobile = false}) {
    final bool isAnySettingsSelected =
        _selectedIndex >= 10 && _selectedIndex <= 12;

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
                  isMobile: isMobile,
                ),
                _buildNavItem(
                  11,
                  Icons.integration_instructions_rounded,
                  'Integrations',
                  isSubItem: true,
                  isMobile: isMobile,
                ),
                _buildNavItem(
                  12,
                  Icons.replay_circle_filled_outlined,
                  'Retry System',
                  isSubItem: true,
                  isMobile: isMobile,
                ),
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

  Widget _buildExpandableReportsMenu({bool isMobile = false}) {
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
                  isMobile: isMobile,
                ),
                if (!isMobile)
                  _buildNavItem(
                    6,
                    Icons.insights_rounded,
                    'Meta Analytics',
                    isSubItem: true,
                    isMobile: isMobile,
                  ),
                _buildNavItem(
                  7,
                  Icons.schedule_rounded,
                  'Scheduled',
                  isSubItem: true,
                  isMobile: isMobile,
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
    bool isMobile = false,
  }) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        _setSelectedIndex(index);
        if (isMobile) {
          Navigator.pop(context);
        }
      },
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
  static const _cachedPhoneNumbersKey = 'cached_waba_phone_numbers';
  static const _cachedPhoneWabaKey = 'cached_waba_id_for_phones';

  /// Load phone numbers that were previously saved to SharedPreferences.
  /// This is essential for mobile where direct Meta API calls may fail.
  Future<void> _loadCachedPhoneNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wabaId = prefs.getString(_cachedPhoneWabaKey);
      final json = prefs.getString(_cachedPhoneNumbersKey);
      if (wabaId != null && json != null) {
        final list = (jsonDecode(json) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _headerWabaId = wabaId;
            _headerPhoneNumbers = list;
            _fetchedHeaderPhoneNumbers = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchHeaderPhoneNumbers(
    String wabaId,
    String accessToken,
  ) async {
    if (_loadingHeaderPhoneNumbers) return;
    _loadingHeaderPhoneNumbers = true;
    _headerWabaId = wabaId;
    try {
      final numbers = await getIt<WhatsAppRepository>().fetchPhoneNumbers(
        wabaId: wabaId,
        accessToken: accessToken,
      );
      if (numbers != null && numbers.isNotEmpty) {
        // Persist for future sessions (especially mobile where direct API may fail)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cachedPhoneWabaKey, wabaId);
          await prefs.setString(_cachedPhoneNumbersKey, jsonEncode(numbers));
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _headerPhoneNumbers = numbers ?? _headerPhoneNumbers; // keep cached if API returned null
          _fetchedHeaderPhoneNumbers = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fetchedHeaderPhoneNumbers = true;
        });
      }
    } finally {
      _loadingHeaderPhoneNumbers = false;
      if (mounted) {
        setState(() {});
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

  Widget _buildHeaderPhoneSelector(Map<String, dynamic> config, {bool isMobile = false}) {
    final wabaId = config['businessAccountId']?.toString();
    final accessToken = config['accessToken']?.toString();
    final currentPhoneId = config['phoneNumberId']?.toString();

    // Fetch phone numbers once per WABA ID. Re-fetch if WABA ID changes.
    if (wabaId != null &&
        accessToken != null &&
        wabaId.isNotEmpty &&
        accessToken.isNotEmpty &&
        (_headerWabaId != wabaId || !_fetchedHeaderPhoneNumbers) &&
        !_loadingHeaderPhoneNumbers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_headerWabaId != wabaId || !_fetchedHeaderPhoneNumbers) && !_loadingHeaderPhoneNumbers) {
          _fetchHeaderPhoneNumbers(wabaId, accessToken);
        }
      });
    }

    if (currentPhoneId == null || currentPhoneId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isHeaderUpdatingPhone) {
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

    final List<Map<String, dynamic>> itemsList = [];
    final Set<String> seenIds = {};

    void addPhoneItem(dynamic item) {
      if (item == null) return;
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ??
            map['phoneNumberId']?.toString() ??
            map['phone_number_id']?.toString();
        if (id != null && id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          itemsList.add({
            'id': id,
            'display_phone_number': map['display_phone_number']?.toString() ??
                map['displayPhone']?.toString() ??
                map['phoneNumber']?.toString() ??
                map['phone_number']?.toString() ??
                id,
            'verified_name': map['verified_name']?.toString() ??
                map['verifiedName']?.toString() ??
                config['verifiedName']?.toString() ??
                '',
            'quality_rating': map['quality_rating']?.toString() ??
                map['qualityRating']?.toString() ??
                'GREEN',
            'throughput': map['throughput'],
          });
        }
      } else if (item is String && item.isNotEmpty && !seenIds.contains(item)) {
        seenIds.add(item);
        itemsList.add({
          'id': item,
          'display_phone_number': item,
          'verified_name': config['verifiedName']?.toString() ?? '',
          'quality_rating': 'GREEN',
        });
      }
    }

    // 1. Add active phone number from current config
    if (currentPhoneId.isNotEmpty) {
      addPhoneItem({
        'id': currentPhoneId,
        'display_phone_number': config['displayPhone'] ??
            config['display_phone_number'] ??
            config['phoneNumber'] ??
            'Active Number',
        'verified_name': config['verifiedName'] ?? 'Verified Name',
        'quality_rating': config['qualityRating'] ?? 'GREEN',
      });
    }

    // 2. Add phone numbers fetched from Meta Graph API
    for (final p in _headerPhoneNumbers) {
      addPhoneItem(p);
    }

    // 3. Add any additional phone numbers saved in tenant config
    final rawConfigLists = [
      config['phoneNumbers'],
      config['availablePhoneNumbers'],
      config['phone_numbers'],
      config['allPhoneNumbers'],
      config['numbers'],
      config['phoneList'],
    ];

    for (final listObj in rawConfigLists) {
      if (listObj is List) {
        for (final item in listObj) {
          addPhoneItem(item);
        }
      }
    }

    return Container(
      height: isMobile ? 36 : 42,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentPhoneId,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppTheme.secondaryColor,
            size: isMobile ? 18 : 24,
          ),
          style: TextStyle(fontSize: isMobile ? 11 : 13, color: Colors.black87),
          selectedItemBuilder: (context) {
            return itemsList.map<Widget>((phone) {
              final displayPhone = phone['display_phone_number']?.toString() ??
                  phone['displayPhone']?.toString() ??
                  phone['phoneNumber']?.toString() ??
                  config['displayPhone']?.toString() ??
                  'Active Number';
              final id = phone['id']?.toString() ?? '';
              return Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 125 : 180),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        id == currentPhoneId
                            ? Icons.check_circle
                            : Icons.phone_android_rounded,
                        color: id == currentPhoneId ? Colors.green : Colors.grey,
                        size: isMobile ? 13 : 16,
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Flexible(
                        child: Text(
                          displayPhone,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 11 : 13,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
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
              child: SizedBox(
                width: isMobile ? 240 : 280,
                child: Row(
                  children: [
                    Icon(
                      id == currentPhoneId
                          ? Icons.check_circle
                          : Icons.phone_android_rounded,
                      color: id == currentPhoneId ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayPhone,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 12 : 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (verifiedName.isNotEmpty)
                            Text(
                              verifiedName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildHeaderBadgeWidget(rating),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return _buildMobileHeader();
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  '${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year.toString().substring(2)}';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpired
                          ? 'Expired'
                          : 'Dashboard Exp on $expStr',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
          const Spacer(),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is AuthAuthenticated) {
                final config =
                    authState.tenant['whatsappConfig'] as Map<String, dynamic>?;
                if (config != null &&
                    config['accessToken'] != null &&
                    config['accessToken'].toString().isNotEmpty) {
                  return _buildHeaderPhoneSelector(config, isMobile: false);
                }
              }
              return const SizedBox.shrink();
            },
          ),
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
          const SizedBox(width: 8),

          // Support button
          const _SupportButton(isMobile: false),
          const SizedBox(width: 8),
          const VerticalDivider(indent: 20, endIndent: 20),
          const SizedBox(width: 24),
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
              final firstLetter = displayName.characters.isNotEmpty
                  ? displayName.characters.first.toUpperCase()
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
                    _showLogoutDialog(context, displayName);
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
                child: Row(
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
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Logo only
          Image.asset(
            'assets/images/logo.png',
            height: 22,
          ),

          // Right: Phone Selector, Support Button, and Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  if (authState is AuthAuthenticated) {
                    final config =
                        authState.tenant['whatsappConfig'] as Map<String, dynamic>?;
                    if (config != null &&
                        config['accessToken'] != null &&
                        config['accessToken'].toString().isNotEmpty) {
                      return _buildHeaderPhoneSelector(config, isMobile: true);
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(width: 4),
              const _SupportButton(isMobile: true),
              const SizedBox(width: 4),
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
                  }
                  final firstLetter = name.characters.isNotEmpty
                      ? name.characters.first.toUpperCase()
                      : 'U';

                  return PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'profile') {
                        _setSelectedIndex(10);
                      } else if (value == 'logout') {
                        _showLogoutDialog(context, name);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            if (authState is! AuthAuthenticated) return const SizedBox.shrink();
                            final subscription =
                                authState.tenant['subscription'] as Map<String, dynamic>?;
                            final expiryDateStr = subscription?['expiryDate'];
                            if (expiryDateStr == null) return const SizedBox.shrink();

                            final exp = DateTime.parse(expiryDateStr as String);
                            final daysLeft = exp.difference(DateTime.now()).inDays;
                            final isExpired = daysLeft < 0;
                            final color = isExpired ? Colors.red : AppTheme.secondaryColor;
                            final expStr =
                                '${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year.toString().substring(2)}';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isExpired
                                        ? Icons.warning_amber_rounded
                                        : Icons.calendar_month_outlined,
                                    size: 13,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isExpired
                                        ? 'Expired'
                                        : 'Exp on $expStr ($daysLeft d)',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18),
                            const SizedBox(width: 8),
                            Text('Profile ($name)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.secondaryColor,
                      child: Text(
                        firstLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
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
  final bool isMobile;
  const _SupportButton({this.isMobile = false});

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
    final borderRadiusVal = isMobile ? 100.0 : 10.0;
    final bgAlpha = isMobile ? 0.05 : 0.08;
    final borderAlpha = isMobile ? 0.15 : 0.2;
    final iconSize = isMobile ? 14.0 : 17.0;

    return Tooltip(
      message: 'Support',
      child: InkWell(
        onTap: () => _showSupportDialog(context),
        borderRadius: BorderRadius.circular(borderRadiusVal),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: isMobile ? 5 : 8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(borderRadiusVal),
            border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: borderAlpha)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.headset_mic_rounded,
                size: iconSize,
                color: AppTheme.secondaryColor,
              ),
              if (!isMobile) ...[
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

