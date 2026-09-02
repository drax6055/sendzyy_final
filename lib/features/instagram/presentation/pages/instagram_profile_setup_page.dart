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

  Map<String, dynamic>? _insightsProfile;
  List<dynamic> _mediaList = [];
  bool _isLoadingInsights = false;
  String? _insightsError;
  int _activeMediaTab = 0; // 0 = Posts, 1 = Reels

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
        // If connected, fetch detailed profile and insights automatically
        if (response.data['connected'] == true) {
          _fetchDetailedProfile();
          _fetchInsightsData();
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

  Future<void> _fetchInsightsData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInsights = true;
      _insightsError = null;
    });

    try {
      final profileRes = await _dio.get('/api/instagram/insights-profile');
      final mediaRes = await _dio.get('/api/instagram/media');

      if (mounted) {
        setState(() {
          _insightsProfile = profileRes.data;
          _mediaList = mediaRes.data is Map && mediaRes.data['data'] != null
              ? (mediaRes.data['data'] as List)
              : (mediaRes.data is List ? mediaRes.data : []);
          _isLoadingInsights = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _insightsError = e.toString();
          _isLoadingInsights = false;
        });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
        ),

        const SizedBox(height: 24),

        // NEW White Background Container - Live Instagram Profile Insights & Media Feed
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Instagram Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingInsights)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: _fetchInsightsData,
                      tooltip: 'Refresh Profile Data',
                    ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoadingInsights && _insightsProfile == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_insightsProfile != null) ...[
                // Profile Banner: Centered & Larger Avatar, Name, and Stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Larger Profile Picture (84x84)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: _insightsProfile!['profile_picture_url'] != null
                              ? NetworkImage(_insightsProfile!['profile_picture_url'])
                              : null,
                          child: _insightsProfile!['profile_picture_url'] == null
                              ? const Icon(Icons.person, size: 42, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Text(
                        _insightsProfile!['name'] ?? _insightsProfile!['username'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_insightsProfile!['username'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${_insightsProfile!['username']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Single Line Centered Stats: Posts | Followers | Following
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Posts', _insightsProfile!['media_count'] ?? 0),
                            _buildStatDivider(),
                            _buildStatItem('Followers', _insightsProfile!['followers_count'] ?? 0),
                            _buildStatDivider(),
                            _buildStatItem('Following', _insightsProfile!['follows_count'] ?? 0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Separate 2-Tab Selector: Posts vs Reels
                Builder(
                  builder: (context) {
                    final postsList = _mediaList.where((m) {
                      final type = (m['media_type'] ?? '').toString().toUpperCase();
                      final productType = (m['media_product_type'] ?? '').toString().toUpperCase();
                      return type != 'VIDEO' && productType != 'REELS';
                    }).toList();

                    final reelsList = _mediaList.where((m) {
                      final type = (m['media_type'] ?? '').toString().toUpperCase();
                      final productType = (m['media_product_type'] ?? '').toString().toUpperCase();
                      return type == 'VIDEO' || productType == 'REELS';
                    }).toList();

                    final currentDisplayList = _activeMediaTab == 0 ? postsList : reelsList;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildTabChip(
                              index: 0,
                              icon: Icons.grid_on_rounded,
                              label: 'Posts (${postsList.length})',
                            ),
                            const SizedBox(width: 12),
                            _buildTabChip(
                              index: 1,
                              icon: Icons.video_collection_rounded,
                              label: 'Reels (${reelsList.length})',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (currentDisplayList.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: Text(
                              _activeMediaTab == 0
                                  ? 'No image posts found on this account.'
                                  : 'No reels or videos found on this account.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentDisplayList.length,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (context, index) {
                              final media = currentDisplayList[index];
                              final mediaType = (media['media_type'] ?? '').toString().toUpperCase();
                              final isVideo = mediaType == 'VIDEO' || (media['media_product_type'] ?? '').toString().toUpperCase() == 'REELS';
                              final imageUrl = isVideo ? (media['thumbnail_url'] ?? media['media_url']) : media['media_url'];

                              return InkWell(
                                onTap: () => _showMediaDetailDialog(media),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade100,
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (imageUrl != null && imageUrl.toString().isNotEmpty)
                                        Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        )
                                      else
                                        Container(
                                          color: Colors.grey.shade200,
                                          child: Icon(
                                            isVideo ? Icons.videocam : Icons.image,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),

                                      Positioned(
                                        left: 0, right: 0, bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                          child: Text(
                                            media['caption'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontSize: 11),
                                          ),
                                        ),
                                      ),

                                      if (isVideo)
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.65),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                          ),
                                        ),

                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isVideo ? Icons.videocam_rounded : Icons.photo_library_rounded,
                                                color: Colors.white,
                                                size: 11,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                isVideo ? 'REEL' : 'POST',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ] else if (_insightsError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Failed to load Instagram media & insights: $_insightsError',
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchInsightsData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(
                        'Connect your Instagram account to view live Insights & Media Feed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
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

  Widget _buildStatItem(String label, dynamic count) {
    final number = int.tryParse(count.toString()) ?? 0;
    final formattedNumber = NumberFormat.compact().format(number);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedNumber,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildTabChip({required int index, required IconData icon, required String label}) {
    final isSelected = _activeMediaTab == index;
    return InkWell(
      onTap: () => setState(() => _activeMediaTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaDetailDialog(Map<String, dynamic> media) {
    final mediaUrl = media['media_url']?.toString();
    final permalink = media['permalink']?.toString();
    final mediaType = (media['media_type'] ?? '').toString().toUpperCase();
    final isVideo = mediaType == 'VIDEO' || (media['media_product_type'] ?? '').toString().toUpperCase() == 'REELS';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isVideo ? Icons.video_collection_rounded : Icons.grid_on_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVideo ? 'Instagram Reel / Video' : 'Instagram Post',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isVideo && mediaUrl != null)
                Container(
                  height: 460,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          media['thumbnail_url'] ?? mediaUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.videocam, color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                      Container(color: Colors.black26),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (mediaUrl.isNotEmpty) {
                            html.window.open(mediaUrl, '_blank');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                        label: const Text(
                          'Play Video / Reel',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )
              else if (mediaUrl != null)
                Container(
                  height: 460,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      mediaUrl,
                      height: 460,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

              if (media['caption'] != null && media['caption'].toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  media['caption'],
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  if (permalink != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => html.window.open(permalink, '_blank'),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open on Instagram'),
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
}
