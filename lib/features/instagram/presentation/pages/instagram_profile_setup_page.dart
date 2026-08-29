import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class InstagramProfileSetupPage extends StatefulWidget {
  const InstagramProfileSetupPage({super.key});

  @override
  State<InstagramProfileSetupPage> createState() => _InstagramProfileSetupPageState();
}

class _InstagramProfileSetupPageState extends State<InstagramProfileSetupPage> {
  final Dio _dio = getIt<Dio>();
  bool _isLoading = true;
  Map<String, dynamic>? _instagramProfile;
  Map<String, dynamic>? _detailedProfile;
  String? _errorMessage;
  bool _isRefreshingDetail = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.get('/api/instagram/profile');
      if (mounted) {
        setState(() {
          _instagramProfile = response.data;
          _isLoading = false;
        });
        // If connected, fetch detailed profile automatically
        if (response.data['connected'] == true) {
          _fetchDetailedProfile();
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['error']?.toString() ?? 'Failed to load Instagram profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDetailedProfile() async {
    if (!mounted) return;
    setState(() => _isRefreshingDetail = true);

    try {
      final response = await _dio.get('/api/instagram/detailed-profile');
      if (mounted) {
        setState(() {
          _detailedProfile = response.data;
          _isRefreshingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshingDetail = false);
      }
    }
  }

  Future<void> _disconnectProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect Instagram Account?'),
        content: const Text(
          'Are you sure you want to disconnect your Instagram Business profile? This will stop all automation features and message tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _dio.post('/api/instagram/disconnect');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instagram account disconnected successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProfile();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.response?.data?['error']?.toString() ?? 'Disconnect failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool privacyAccepted = false;
        bool termsAccepted = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Connect Your Instagram Account',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: Container(
                width: 600, // Constrain width of the dialog content
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect your Instagram account securely with Sendzyy to manage your Instagram profile and automation features.',
                        style: TextStyle(height: 1.4, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'When you click Connect Instagram, you will be redirected to Instagram’s official login page. Please enter your Instagram credentials there to authorize the connection.',
                        style: TextStyle(height: 1.4, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your credentials are never stored or accessed by Sendzyy.',
                        style: TextStyle(
                          height: 1.4,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CheckboxListTile(
                        value: privacyAccepted,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppTheme.primaryColor,
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    html.window.open('https://sendzyy.com/privacy', '_blank');
                                  },
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() => privacyAccepted = val ?? false);
                        },
                      ),
                      CheckboxListTile(
                        value: termsAccepted,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AppTheme.primaryColor,
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    html.window.open('https://sendzyy.com/terms', '_blank');
                                  },
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() => termsAccepted = val ?? false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                  child: ElevatedButton(
                    onPressed: (privacyAccepted && termsAccepted)
                        ? () async {
                            Navigator.pop(dialogCtx);
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('auth_token') ?? '';
                            final authUrl = '${AppConstants.baseUrl}/api/instagram/auth?token=$token';
                            html.window.open(authUrl, '_blank');
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Connect Instagram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _instagramProfile != null && (_instagramProfile!['connected'] ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile & Setup',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect and configure your Instagram Business Profile',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!isConnected && !_isLoading)
                Tooltip(
                  message: 'Connect Instagram',
                  child: ElevatedButton(
                    onPressed: _showConnectionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Connect Now',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ),
              if (isConnected && !_isLoading)
                OutlinedButton.icon(
                  onPressed: _disconnectProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    minimumSize: const Size(120, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),

          // Main Content Area
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 64.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Center(
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
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try Again'),
                    )
                  ],
                ),
              ),
            )
          else if (isConnected)
            _buildConnectedUI()
          else
            _buildDisconnectedUI(),
        ],
      ),
    );
  }

  Widget _buildConnectedUI() {
    final String username = _detailedProfile?['username']?.toString()
        ?? _instagramProfile!['username']?.toString()
        ?? 'Unknown User';
    final String name = _detailedProfile?['name']?.toString()
        ?? _instagramProfile!['name']?.toString()
        ?? username;
    final String id = _instagramProfile!['instagramAccountId']?.toString() ?? 'N/A';
    final String? tokenExpiryStr = _instagramProfile!['tokenExpiry']?.toString();

    // Detailed profile data (from Graph API)
    final String? profilePic = _detailedProfile?['profile_picture_url']?.toString();
    final dynamic followerRaw = _detailedProfile?['followers_count'];
    final int? followerCount = followerRaw is int ? followerRaw : (followerRaw != null ? int.tryParse(followerRaw.toString()) : null);
    final bool? isUserFollowBusiness = _detailedProfile?['is_user_follow_business'] as bool?;
    final bool? isBusinessFollowUser = _detailedProfile?['is_business_follow_user'] as bool?;

    String expiryFormatted = 'N/A';
    if (tokenExpiryStr != null && tokenExpiryStr.isNotEmpty) {
      try {
        final DateTime dt = DateTime.parse(tokenExpiryStr).toLocal();
        expiryFormatted = DateFormat('dd-MMM-yyyy').format(dt).toLowerCase();
      } catch (e) {
        expiryFormatted = 'N/A';
      }
    }

    String maskedId = id;
    if (id != 'N/A' && id.length > 6) {
      maskedId = '${id.substring(0, 6)}${'*' * (id.length - 6)}';
    }

    String formatCount(int count) {
      if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
      if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
      return count.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile picture with Instagram gradient border
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFFFB700),
                          Color(0xFFFF007F),
                          Color(0xFF8000FF),
                        ],
                        center: Alignment(0.6, -0.6),
                        radius: 1.0,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade100,
                      child: profilePic != null
                          ? ClipOval(
                              child: Image.network(
                                profilePic,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_circle_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.account_circle_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + Connected badge
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                border: Border.all(color: Colors.green.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Connected',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Instagram ID: $maskedId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        // Detailed profile chips
                        if (_isRefreshingDetail) ...[
                          const SizedBox(height: 12),
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ] else if (_detailedProfile != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (followerCount != null)
                                _buildInfoChip(
                                  icon: Icons.people_alt_outlined,
                                  label: '${formatCount(followerCount)} Followers',
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Top-right: token expiry + refresh button + info button
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (expiryFormatted != 'N/A') ...[
                  Text(
                    'Token Expiry: $expiryFormatted',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Refresh detailed profile button
                Tooltip(
                  message: 'Refresh Profile Details',
                  child: IconButton(
                    icon: _isRefreshingDetail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh_rounded, color: Colors.blue.shade400, size: 20),
                    onPressed: _isRefreshingDetail ? null : _fetchDetailedProfile,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.info_outline_rounded, color: Colors.red.shade400, size: 20),
                  onPressed: () => _showTokenInfoDialog(context),
                  tooltip: 'Token Info',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Text(
                'Connection Token Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Instagram connection token automatically refreshes 7 to 15 days before it expires. To ensure this happens, you must keep your app.sendzyy.com dashboard active.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'When will you need to reconnect manually?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('If you haven\'t opened the app for a long time and the token has already expired.'),
                _buildBulletPoint('If you recently changed your Instagram account password.'),
                _buildBulletPoint('If you removed the app connection from your Facebook or Instagram settings.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedUI() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          // Logo/Icon
          Container(
            width: 80,
            height: 80,
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
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.instagram,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connect Your Instagram Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Link your Instagram Business Profile with Sendzyy to start automating comments, messages, content delivery, and collecting analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 40),
          Tooltip(
            message: 'Connect Instagram',
            child: ElevatedButton.icon(
              onPressed: _showConnectionDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                'Connect Account Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
