import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/login_page.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/js/meta_signup_helper.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/onboarding_checklist_widget.dart';
import 'package:iFloraBuzz/features/templates/presentation/pages/create_template_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:iFloraBuzz/core/widgets/password_verification_dialog.dart';

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

  // WhatsApp Profile Form state
  Map<String, dynamic>? _whatsappProfile;
  bool _whatsappProfileLoading = false;
  String? _whatsappProfileError;
  bool _isSavingWhatsAppProfile = false;
  bool _isProfileEditing = false;
  double _uploadProgress = 0.0;
  bool _isUploadingImage = false;

  final _aboutController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  List<TextEditingController> _websiteControllers = [];
  String? _selectedVertical;

  final Map<String, String> _verticals = {
    'AUTOMOTIVE': 'Automotive',
    'BEAUTY': 'Beauty, Spa & Salon',
    'CONVENIENCE_STORE': 'Convenience Store',
    'DENTIST': 'Dentist',
    'EDUCATION': 'Education',
    'ENTERTAINMENT': 'Entertainment',
    'FINANCE': 'Finance & Banking',
    'HEALTH_MEDICAL': 'Health & Medical',
    'HOTEL_LODGING': 'Hotel & Lodging',
    'INTEGRATOR': 'Integrator',
    'NOT_A_BUSINESS': 'Not a Business',
    'OTHER': 'Other',
    'PARK_GARDEN': 'Park & Garden',
    'REST_CAFE': 'Restaurant & Cafe',
    'RETAIL': 'Shopping & Retail',
    'SPECIALTY_FOOD': 'Specialty Food',
    'TRAVEL_TRANSPORT': 'Travel & Transportation',
    'UTILITY': 'Utility',
  };

  void _initProfileFormFields() {
    if (_whatsappProfile == null) return;
    _aboutController.text = _whatsappProfile!['about']?.toString() ?? '';
    _addressController.text = _whatsappProfile!['address']?.toString() ?? '';
    _descriptionController.text =
        _whatsappProfile!['description']?.toString() ?? '';
    _emailController.text = _whatsappProfile!['email']?.toString() ?? '';

    final List<dynamic> websites = _whatsappProfile!['websites'] ?? [];
    _websiteControllers = websites
        .map((w) => TextEditingController(text: w.toString()))
        .toList();
    if (_websiteControllers.isEmpty) {
      _websiteControllers.add(TextEditingController());
    }

    _selectedVertical = _whatsappProfile!['vertical']?.toString();
  }

  List<Map<String, dynamic>> _phoneNumbers = [];
  bool _loadingPhoneNumbers = false;
  String? _phoneNumbersError;
  String? _fetchedWabaId;
  bool _isUpdatingPhone = false;

  Future<void> _fetchPhoneNumbers(String wabaId, String accessToken) async {
    if (_loadingPhoneNumbers) return;
    setState(() {
      _loadingPhoneNumbers = true;
      _phoneNumbersError = null;
      _fetchedWabaId = wabaId;
    });
    try {
      final numbers = await getIt<WhatsAppRepository>().fetchPhoneNumbers(
        wabaId: wabaId,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          _phoneNumbers = numbers ?? [];
          _loadingPhoneNumbers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneNumbersError = 'Failed to load phone numbers';
          _loadingPhoneNumbers = false;
        });
      }
    }
  }

  Future<void> _updateActivePhoneNumber(
    Map<String, dynamic> phone,
    Map<String, dynamic> config,
  ) async {
    setState(() {
      _isUpdatingPhone = true;
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
          _isUpdatingPhone = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    for (var c in _websiteControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleProfileInfo() async {
    if (_showProfileInfo) {
      setState(() => _showProfileInfo = false);
      return;
    }
    setState(() {
      _showProfileInfo = true;
      _profileLoading = true;
      _whatsappProfileLoading = true;
      _whatsappProfileError = null;
    });
    try {
      final profile = await getIt<WhatsAppRepository>().getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _profileLoading = false;
        });
      }

      final config = profile['whatsappConfig'] ?? {};
      final phoneId = config['phoneNumberId']?.toString();
      final token = config['accessToken']?.toString();

      if (phoneId != null &&
          token != null &&
          phoneId.isNotEmpty &&
          token.isNotEmpty) {
        final waProfile = await getIt<WhatsAppRepository>()
            .fetchWhatsAppProfile(phoneNumberId: phoneId, accessToken: token);
        if (mounted) {
          setState(() {
            _whatsappProfile = waProfile ?? <String, dynamic>{};
            _whatsappProfileLoading = false;
            _initProfileFormFields();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _whatsappProfileLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _profileLoading = false;
          _whatsappProfileLoading = false;
          _whatsappProfileError = cleanMsg;
        });
      }
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
    } catch (_) {
      return value.toString();
    }
  }

  String _daysLeft(dynamic expiresAt) {
    if (expiresAt == null) return 'N/A';
    try {
      final diff = DateTime.parse(
        expiresAt.toString(),
      ).toLocal().difference(DateTime.now()).inDays;
      if (diff < 0) return 'Expired';
      return '$diff days left';
    } catch (_) {
      return 'N/A';
    }
  }

  Color _expiryColor(dynamic expiresAt) {
    if (expiresAt == null) return Colors.grey;
    try {
      final diff = DateTime.parse(
        expiresAt.toString(),
      ).toLocal().difference(DateTime.now()).inDays;
      if (diff < 0) return Colors.red;
      if (diff <= 7) return Colors.orange;
      return Colors.green;
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final bool isConnected =
            state is AuthAuthenticated &&
            state.tenant['whatsappConfig'] != null &&
            state.tenant['whatsappConfig']['accessToken'] != null &&
            state.tenant['whatsappConfig']['accessToken'].toString().isNotEmpty;

        if (isConnected) {
          final wabaId = state.tenant['whatsappConfig']['businessAccountId']
              ?.toString();
          final accessToken = state.tenant['whatsappConfig']['accessToken']
              ?.toString();
          if (wabaId != null &&
              accessToken != null &&
              wabaId != _fetchedWabaId &&
              !_loadingPhoneNumbers) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchPhoneNumbers(wabaId, accessToken);
            });
          }
        }

        return LayoutBuilder(
          builder: (context, outerConstraints) {
          final isMobileLayout = outerConstraints.maxWidth < 600;
          return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobileLayout ? 0 : 25,
            vertical: 0,
          ),
          color: AppTheme.backgroundColor,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobileLayout ? 16 : 32),
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
                    ? _buildConnectedDetailsCard(
                        context,
                        state.tenant['whatsappConfig'],
                      )
                    : _buildConnectMetaCard(context),

                const SizedBox(height: 32),

                OnboardingChecklistWidget(
                  onSetupWhatsApp: () {
                    if (!isConnected) {
                      _connectMeta();
                    }
                  },
                  onCreateTemplate: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateTemplatePage(),
                      ),
                    );
                  },
                ),

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
                  child: _buildProfileContent(
                    context,
                    isConnected
                        ? (state as AuthAuthenticated)
                                  .tenant['whatsappConfig'] ??
                              {}
                        : {},
                    isConnected,
                  ),
                ),

                const SizedBox(height: 12),
                _buildPlaceholderTile(
                  'Security & Password',
                  Icons.lock_outline,
                  () => _showChangePasswordDialog(context),
                ),

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
      },
    );
  }

  Widget _buildRenewPlanTile(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const SizedBox.shrink();
        }

        final subscription =
            authState.tenant['subscription'] as Map<String, dynamic>?;
        final expiryDateStr = subscription?['expiryDate'];
        final expiresAt = expiryDateStr != null
            ? DateTime.parse(expiryDateStr as String)
            : null;

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final iconWidget = Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.secondaryColor,
                size: 20,
              ),
            );

            final textInfoWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Panel Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Expires $expiryDateFormatted',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );

            final badgeWidget = daysLeft != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      expiryLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  )
                : null;

            final renewButton = ElevatedButton.icon(
              onPressed: widget.onRenewPlan,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Renew Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired || isWarning
                    ? badgeColor
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            iconWidget,
                            const SizedBox(width: 14),
                            Expanded(child: textInfoWidget),
                            if (badgeWidget != null) badgeWidget,
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: renewButton,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        iconWidget,
                        const SizedBox(width: 16),
                        Expanded(child: textInfoWidget),
                        if (badgeWidget != null) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: badgeWidget,
                          ),
                        ],
                        SizedBox(
                          width: 130,
                          child: renewButton,
                        ),
                      ],
                    ),
            );
          },
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
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
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
                  Icon(
                    icon,
                    color: isExpanded ? AppTheme.primaryColor : Colors.blueGrey,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: isExpanded
                          ? AppTheme.primaryColor
                          : Colors.black87,
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
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic> config,
    bool isConnected,
  ) {
    if (_profileLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_profile == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Failed to load profile',
            style: TextStyle(color: Colors.grey),
          ),
        ),
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

          // ── Account Info ──
          _sectionHeader(Icons.person_outline, 'Account Info'),
          const SizedBox(height: 14),
          _infoRow('Name', _profile!['name']?.toString() ?? 'N/A'),
          _infoRow('Email', _profile!['email']?.toString() ?? 'N/A'),
          _infoRow(
            'Member Since',
            _formatDate(
              _profile!['createdAt'] ??
                  _profile!['subscription']?['lastPaymentDate'],
            ),
          ),

          if (sub != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── Subscription ──
            _sectionHeader(Icons.workspace_premium, 'Subscription'),
            const SizedBox(height: 14),
            _infoRow(
              'Plan',
              sub['planName']?.toString() ??
                  sub['packageName']?.toString() ??
                  'N/A',
            ),
            _infoRow(
              'Billing Cycle',
              _capitalize(sub['billingCycle']?.toString() ?? 'N/A'),
            ),
            _infoRow('Price', '₹${sub['price'] ?? 'N/A'}'),
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
                    style: TextStyle(
                      color: expiryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              'No active subscription',
              style: TextStyle(color: Colors.grey),
            ),
          ],

          if (isConnected) _buildWhatsAppProfileSection(config),
        ],
      ),
    );
  }

  Widget _buildWhatsAppProfileSection(Map<String, dynamic> config) {
    if (_whatsappProfileLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Fetching WhatsApp profile from Meta...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_whatsappProfileError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            children: [
              Text(
                _whatsappProfileError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _toggleProfileInfo(); // close
                  _toggleProfileInfo(); // open again
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_whatsappProfile == null) {
      return const SizedBox.shrink();
    }

    final activePhoneId = config['phoneNumberId']?.toString();
    String? verifiedName = config['verifiedName']?.toString();

    if (verifiedName == null || verifiedName.isEmpty) {
      if (_phoneNumbers.isNotEmpty && activePhoneId != null) {
        final activePhone = _phoneNumbers.firstWhere(
          (p) => p['id']?.toString() == activePhoneId,
          orElse: () => <String, dynamic>{},
        );
        if (activePhone.isNotEmpty) {
          verifiedName = activePhone['verified_name']?.toString();
        }
      }
    }

    final displayName =
        (verifiedName ?? _profile?['name']?.toString() ?? 'Profile Picture')
            .toUpperCase();

    final avatarUrl = _whatsappProfile!['profile_picture_url']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _sectionHeader(
                Icons.chat_bubble_outline,
                'WhatsApp Business Profile',
              ),
            ),
            IconButton(
              tooltip: _isProfileEditing ? 'Cancel Edit' : 'Edit Profile',
              icon: Icon(
                _isProfileEditing ? Icons.close_rounded : Icons.edit_rounded,
                color: _isProfileEditing
                    ? Colors.redAccent
                    : AppTheme.primaryColor,
              ),
              onPressed: () {
                setState(() {
                  _isProfileEditing = !_isProfileEditing;
                  if (!_isProfileEditing) {
                    _initProfileFormFields();
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Avatar Upload Section
        Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey.shade400,
                        )
                      : null,
                ),
                if (_isUploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (_isProfileEditing)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _pickAndUploadProfileImage(config),
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isProfileEditing
                        ? 'Click image to upload a new profile picture. Meta supports square JPG or PNG files.'
                        : 'WhatsApp Verified Business Profile',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // About Status Text
        TextFormField(
          controller: _aboutController,
          readOnly: !_isProfileEditing,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLength: 139,
          decoration: InputDecoration(
            labelText: 'About Status Text',
            labelStyle: TextStyle(
              color: _isProfileEditing
                  ? AppTheme.primaryColor
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            hintText: 'Hey there! I am using WhatsApp.',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: _isProfileEditing ? Colors.white : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Business Description
        TextFormField(
          controller: _descriptionController,
          readOnly: !_isProfileEditing,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Business Description',
            labelStyle: TextStyle(
              color: _isProfileEditing
                  ? AppTheme.primaryColor
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            hintText:
                'Tell customers about your business vertical, services, or catalog...',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: _isProfileEditing ? Colors.white : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Business Address
        TextFormField(
          controller: _addressController,
          readOnly: !_isProfileEditing,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: 'Business Address',
            labelStyle: TextStyle(
              color: _isProfileEditing
                  ? AppTheme.primaryColor
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            hintText: 'Ahmedabad, Gujarat 380006',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: _isProfileEditing ? Colors.white : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Contact Email
        TextFormField(
          controller: _emailController,
          readOnly: !_isProfileEditing,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Contact Email',
            labelStyle: TextStyle(
              color: _isProfileEditing
                  ? AppTheme.primaryColor
                  : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            hintText: 'info@yourbusiness.com',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: _isProfileEditing ? Colors.white : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Industry Vertical Dropdown
        Text(
          'Business Vertical Category',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _isProfileEditing
                ? AppTheme.primaryColor
                : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedVertical,
          isExpanded: true,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          disabledHint: Text(
            _verticals[_selectedVertical] ?? _selectedVertical ?? 'None',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: _isProfileEditing ? Colors.white : Colors.grey.shade50,
          ),
          dropdownColor: Colors.white,
          items: _verticals.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: _isProfileEditing
              ? (val) {
                  setState(() {
                    _selectedVertical = val;
                  });
                }
              : null,
        ),
        const SizedBox(height: 24),

        // Websites Editor
        _buildWebsitesEditor(),

        if (_isProfileEditing) ...[
          const SizedBox(height: 32),
          // Save Button
          ElevatedButton(
            onPressed: _isSavingWhatsAppProfile
                ? null
                : () => _saveWhatsAppProfile(config),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSavingWhatsAppProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save WhatsApp Business Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildWebsitesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Websites',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _isProfileEditing
                ? AppTheme.primaryColor
                : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_websiteControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _websiteControllers[index],
                    readOnly: !_isProfileEditing,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: _isProfileEditing
                          ? Colors.white
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isProfileEditing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _websiteControllers[index].dispose();
                        _websiteControllers.removeAt(index);
                        if (_websiteControllers.isEmpty) {
                          _websiteControllers.add(TextEditingController());
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        }),
        if (_isProfileEditing && _websiteControllers.length < 2)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _websiteControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Another Website'),
          )
        else if (_isProfileEditing && _websiteControllers.length >= 2)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Maximum 2 websites allowed by Meta.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndUploadProfileImage(Map<String, dynamic> config) async {
    final phoneId = config['phoneNumberId']?.toString();
    final token = config['accessToken']?.toString();
    if (phoneId == null || token == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (!kIsWeb && file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) return;

        setState(() {
          _isUploadingImage = true;
          _uploadProgress = 0.0;
        });

        final handleId = await getIt<WhatsAppRepository>()
            .uploadWhatsAppProfileImage(
              phoneNumberId: phoneId,
              accessToken: token,
              imageBytes: bytes,
              fileName: file.name,
              mimeType: file.extension == 'png' ? 'image/png' : 'image/jpeg',
              onProgress: (progress) {
                setState(() {
                  _uploadProgress = progress;
                });
              },
            );

        if (handleId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture uploaded successfully!'),
              ),
            );
          }
          _whatsappProfile = null;
          _toggleProfileInfo();
          _toggleProfileInfo();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload profile picture')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _saveWhatsAppProfile(Map<String, dynamic> config) async {
    final phoneId = config['phoneNumberId']?.toString();
    final token = config['accessToken']?.toString();
    if (phoneId == null || token == null) return;

    setState(() {
      _isSavingWhatsAppProfile = true;
    });

    final aboutText = _aboutController.text.trim();
    if (aboutText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('About Status Text is required and cannot be empty.'),
          ),
        );
      }
      setState(() {
        _isSavingWhatsAppProfile = false;
      });
      return;
    }

    final websites = _websiteControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    for (var w in websites) {
      if (!w.startsWith('http://') && !w.startsWith('https://')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid website: $w. Must start with http:// or https://',
              ),
            ),
          );
        }
        setState(() {
          _isSavingWhatsAppProfile = false;
        });
        return;
      }
    }

    final Map<String, dynamic> profileData = {'about': aboutText};

    final addressText = _addressController.text.trim();
    if (addressText.isNotEmpty) {
      profileData['address'] = addressText;
    }
    final descriptionText = _descriptionController.text.trim();
    if (descriptionText.isNotEmpty) {
      profileData['description'] = descriptionText;
    }
    final emailText = _emailController.text.trim();
    if (emailText.isNotEmpty) {
      profileData['email'] = emailText;
    }
    if (websites.isNotEmpty) {
      profileData['websites'] = websites;
    }
    if (_selectedVertical != null && _selectedVertical!.isNotEmpty) {
      profileData['vertical'] = _selectedVertical;
    }

    try {
      final success = await getIt<WhatsAppRepository>()
          .updateWhatsAppProfileText(
            phoneNumberId: phoneId,
            accessToken: token,
            profileData: profileData,
          );

      if (success) {
        if (mounted) {
          setState(() {
            _isProfileEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp Business Profile updated successfully!'),
            ),
          );
        }
        _toggleProfileInfo();
        _toggleProfileInfo();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update WhatsApp Business Profile'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Displays clean error from Meta if available
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $cleanMsg')),
        );
      }
    } finally {
      setState(() {
        _isSavingWhatsAppProfile = false;
      });
    }
  }

  /// Replace characters outside the PDF default font's Latin-1 range.
  String _pdfSafe(String s) => s
      .replaceAll('\u2014', '-') // em dash â€”
      .replaceAll('\u2013', '-') // en dash â€“
      .replaceAll('\u2018', "'") // left single quote '
      .replaceAll('\u2019', "'") // right single quote '
      .replaceAll('\u201C', '"') // left double quote "
      .replaceAll('\u201D', '"') // right double quote "
      .replaceAll('\u2026', '...') // ellipsis â€¦
      .replaceAll(
        RegExp(r'[^\x00-\xFF]'),
        '?',
      ); // anything else outside Latin-1

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
    final color = isPanelRenewal
        ? PdfColors.purple
        : PdfColor.fromHex('#1DB954');

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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sendzyy',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: color,
                      ),
                    ),
                    pw.Text(
                      'Payment Receipt',
                      style: const pw.TextStyle(
                        fontSize: 13,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date: $dateStr',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Type: $typeLabel',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
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
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Description',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _pdfSafe(description.isNotEmpty ? description : typeLabel),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Details table
            pw.TableHelper.fromTextArray(
              headers: ['Field', 'Value'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: color),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
              data: [
                ['Category', typeLabel],
                ['Date & Time', dateStr],
                if (!isPanelRenewal && credits > 0)
                  ['Credits Added', '+${credits.toStringAsFixed(0)}'],
                ['Status', 'Completed'],
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Thank you for your payment.',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
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
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sendzyy - Payment History',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: $now',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Type', 'Credits'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
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
                (!isPanelRenewal && credits > 0)
                    ? '+${credits.toStringAsFixed(0)}'
                    : '-',
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
              const Text(
                'Failed to load history',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _togglePaymentHistory,
                child: const Text('Retry'),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 15,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Download All',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
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
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No records',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ...current.map(
              (record) => _buildPaymentCard(
                record,
                onDownload: () => _downloadReceipt(record),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    Map<String, dynamic> record, {
    VoidCallback? onDownload,
  }) {
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
    final icon = isPanelRenewal
        ? Icons.workspace_premium_rounded
        : Icons.add_shopping_cart_rounded;
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
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
              child: Icon(
                Icons.download_outlined,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
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
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.secondaryColor,
          ),
        ),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
              onPressed: _connectMeta,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.facebook, size: 24),
              label: Text(
                _isConnecting ? 'Connecting...' : 'Connect Meta Account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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

  Future<void> _connectMeta() async {
    try {
      // Log start event to backend server.log
      await getIt<WhatsAppRepository>().logSignupEvent(eventName: 'START');

      final result = await triggerMetaSignup(
        AppConstants.metaAppId,
        AppConstants.metaConfigId,
      );

      if (result != null && result['status'] == 'success') {
        setState(() => _isConnecting = true);

        final wabaId = result['wabaId'] as String?;
        final phoneNumberId = result['phoneNumberId'] as String?;
        final code = result['code'] as String?;
        final sessionId = result['sessionId'] as String?;
        final sessionInfoResponse = result['sessionInfoResponse'] as String?;

        // Log success at the frontend popup stage
        await getIt<WhatsAppRepository>().logSignupEvent(
          eventName: 'SUCCESS_FRONTEND',
          sessionId: sessionId,
          data: {
            'wabaId': wabaId,
            'phoneNumberId': phoneNumberId,
            'code': code,
            'sessionInfoResponse': sessionInfoResponse,
          },
        );

        // If we have no code but have WABA/phone IDs, proceed with embedded signup
        if ((code == null || code.isEmpty) &&
            (wabaId != null || phoneNumberId != null)) {
          setState(() => _isConnecting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Meta signup incomplete. Please try again or contact support.',
                ),
              ),
            );
          }
          return;
        }

        final response = await getIt<WhatsAppRepository>()
            .facebookEmbeddedSignup(
              code: code ?? '',
              appId: AppConstants.metaAppId,
              wabaId: wabaId,
              phoneNumberId: phoneNumberId,
              sessionId: sessionId,
              sessionInfoResponse: sessionInfoResponse,
              businessPortfolioId:
                  result['businessPortfolioId'] as String?, // Step 3
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
              const SnackBar(
                content: Text('Meta Account Connected Successfully!'),
              ),
            );
          } else {
            // Token saved but IDs missing — show error
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Connection partially completed. Please reconnect your Meta account.',
                ),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to connect Meta account. Please try again.',
              ),
            ),
          );
        }
      } else if (result?['status'] == 'cancelled') {
        // User cancelled — do nothing
        await getIt<WhatsAppRepository>().logSignupEvent(
          eventName: 'CANCELLED_FRONTEND',
          sessionId: result?['sessionId'] as String?,
        );
      } else if (result?['status'] == 'error_sdk_not_loaded') {
        await getIt<WhatsAppRepository>().logSignupEvent(
          eventName: 'ERROR_SDK_NOT_LOADED_FRONTEND',
          data: {'error': result?['sessionInfoResponse'] ?? 'SDK Blocked'},
        );
        setState(() => _isConnecting = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Connection Blocked'),
                ],
              ),
              content: const Text(
                'The Meta/Facebook SDK script was blocked from loading. '
                'This is usually caused by an ad-blocker, privacy extension, or firewall. '
                'Please disable your ad-blocker for this site and try again.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        await getIt<WhatsAppRepository>().logSignupEvent(
          eventName: 'ERROR_FRONTEND',
          sessionId: result?['sessionId'] as String?,
          data: {'status': result?['status']},
        );
        setState(() => _isConnecting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meta signup failed. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      await getIt<WhatsAppRepository>().logSignupEvent(
        eventName: 'FATAL_ERROR_FRONTEND',
        data: {'error': e.toString()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting Meta account: $e')),
        );
      }
    }
  }

  bool _isRegisteringPhone = false;

  void _showRegisterPhoneErrorDialog({
    required BuildContext context,
    required String title,
    required String errorDetail,
    bool isNetworkError = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_disabled_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Phone number could not be registered with Meta',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Error detail box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Detail',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      errorDetail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tips
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'What to try',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...[
                      if (isNetworkError)
                        'Check your internet connection and try again.'
                      else
                        'Ensure your phone number is verified and approved by Meta.',
                      'Make sure your Access Token has the required permissions.',
                      'If the error persists, disconnect and reconnect your Meta account.',
                    ].map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _registerPhoneWithMeta();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Future<void> _registerPhoneWithMeta() async {
    setState(() => _isRegisteringPhone = true);
    try {
      final res = await getIt<WhatsAppRepository>().registerPhoneNumber();
      if (mounted) setState(() => _isRegisteringPhone = false);

      if (res != null && res['success'] == true) {
        if (mounted) {
          // 1. Refresh the auth state so the DB-stored qualityRating is picked up.
          context.read<AuthBloc>().add(AuthCheckRequested());

          // 2. Force the phone-numbers list to re-fetch from Meta so the
          //    quality_rating badge updates immediately without a page reload.
          //    Resetting _fetchedWabaId causes the build() watcher to call
          //    _fetchPhoneNumbers() on the next frame.
          setState(() {
            _fetchedWabaId = null;
            _phoneNumbers = [];
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Phone number registered successfully! Status is now CONNECTED.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // API returned a failure response
        final errDetail =
            res?['error'] ??
            res?['details'] ??
            res?['message'] ??
            'Registration failed. Please try again.';
        if (mounted) {
          _showRegisterPhoneErrorDialog(
            context: context,
            title: 'Registration Failed',
            errorDetail: errDetail.toString(),
          );
        }
      }
    } catch (e) {
      // Network / unexpected exception
      if (mounted) {
        setState(() => _isRegisteringPhone = false);
        final isNetwork =
            e.toString().toLowerCase().contains('socket') ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('timeout');
        _showRegisterPhoneErrorDialog(
          context: context,
          title: isNetwork ? 'Network Error' : 'Unexpected Error',
          errorDetail: e.toString(),
          isNetworkError: isNetwork,
        );
      }
    }
  }

  Widget _buildConnectedDetailsCard(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                Flexible(
                  child: Text(
                    'Meta Account Connected',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Phone Number ID',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: _buildActivePhoneSelector(config),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('WABA ID', config['businessAccountId'] ?? 'N/A'),
            const Divider(height: 32),
            _buildDetailRow(
              'Access Token',
              '••••••••••••••••${config['accessToken']?.toString().substring((config['accessToken']?.toString().length ?? 4) - 4) ?? ''}',
            ),
            if ((config['displayPhone'] as String?)?.isNotEmpty == true) ...[
              const Divider(height: 32),
              _buildDetailRow('Display Phone', config['displayPhone'] ?? ''),
            ],
            if ((config['verifiedName'] as String?)?.isNotEmpty == true) ...[
              const Divider(height: 32),
              _buildDetailRow('Verified Name', config['verifiedName'] ?? ''),
            ],
            if ((config['qualityRating'] as String?)?.isNotEmpty == true) ...[
              const Divider(height: 32),
              _buildQualityRow('Quality Rating', config['qualityRating'] ?? ''),
            ],
            if ((config['throughputLevel'] as String?)?.isNotEmpty == true) ...[
              const Divider(height: 32),
              _buildDetailRow('Throughput', config['throughputLevel'] ?? ''),
            ],
            // Register Phone button — only shown when phone is NOT connected
            Builder(
              builder: (context) {
                final activePhoneId = config['phoneNumberId']?.toString();
                // Look up the status from the fetched phone numbers list
                String? phoneStatus;
                if (_phoneNumbers.isNotEmpty && activePhoneId != null) {
                  final activePhone = _phoneNumbers.firstWhere(
                    (p) => p['id']?.toString() == activePhoneId,
                    orElse: () => <String, dynamic>{},
                  );
                  phoneStatus = activePhone['status']?.toString().toUpperCase();
                }
                // Also fallback to config stored status if available
                phoneStatus ??= config['phoneStatus']?.toString().toUpperCase();

                final isConnected = phoneStatus == 'CONNECTED';

                if (isConnected) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    // Status warning banner
                    if (phoneStatus != null && phoneStatus != 'CONNECTED') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Phone status: $phoneStatus — Messages may fail with error 141000. '
                                'Tap below to register the phone number with Meta Cloud API.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'If you are seeing error 141000, tap below to register your phone number with Meta Cloud API.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isRegisteringPhone
                          ? null
                          : _registerPhoneWithMeta,
                      icon: _isRegisteringPhone
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isRegisteringPhone
                            ? 'Registering Phone...'
                            : 'Register Phone Number (Fix Error 141000)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePhoneSelector(Map<String, dynamic> config) {
    if (_loadingPhoneNumbers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Fetching phone numbers from Meta...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_phoneNumbersError != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _phoneNumbersError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final wabaId = config['businessAccountId']?.toString();
              final accessToken = config['accessToken']?.toString();
              if (wabaId != null && accessToken != null)
                _fetchPhoneNumbers(wabaId, accessToken);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      );
    }

    final currentPhoneId = config['phoneNumberId']?.toString();

    if (_phoneNumbers.isEmpty) {
      return _buildDetailRow('Phone Number ID', currentPhoneId ?? 'N/A');
    }

    final hasCurrent = _phoneNumbers.any(
      (p) => p['id']?.toString() == currentPhoneId,
    );
    final List<Map<String, dynamic>> itemsList = List.from(_phoneNumbers);
    if (!hasCurrent && currentPhoneId != null && currentPhoneId.isNotEmpty) {
      itemsList.insert(0, {
        'id': currentPhoneId,
        'display_phone_number': config['displayPhone'] ?? 'Active Number',
        'verified_name': config['verifiedName'] ?? 'Verified Name',
        'quality_rating': config['qualityRating'] ?? 'UNKNOWN',
        'throughput': {'level': config['throughputLevel']},
      });
    }

    return DropdownButtonFormField<String>(
      value: currentPhoneId,
      isExpanded: true,
      isDense: false,
      itemHeight: 56,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: AppTheme.backgroundColor,
      ),
      dropdownColor: AppTheme.surfaceColor,
      items: itemsList.map((phone) {
        final id = phone['id']?.toString() ?? '';
        final displayPhone =
            phone['display_phone_number']?.toString() ?? 'Unknown Phone';
        final verifiedName = phone['verified_name']?.toString() ?? 'No Name';
        final rating = phone['quality_rating']?.toString() ?? 'UNKNOWN';

        return DropdownMenuItem<String>(
          value: id,
          child: Row(
            children: [
              Icon(
                id == currentPhoneId ? Icons.check_circle : Icons.phone_android,
                color: id == currentPhoneId ? Colors.green : Colors.blueAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayPhone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      verifiedName,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildQualityBadgeWidget(rating),
            ],
          ),
        );
      }).toList(),
      onChanged: _isUpdatingPhone
          ? null
          : (selectedId) async {
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
                  _updateActivePhoneNumber(selectedPhone, config);
                } else {
                  if (mounted) setState(() {});
                }
              }
            },
    );
  }

  Widget _buildQualityBadgeWidget(String value) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  /// Renders quality rating with a color-coded badge (GREEN/YELLOW/RED → colors).
  Widget _buildQualityRow(String label, String value) {
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderTile(
    String title,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
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
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
