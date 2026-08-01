import 'package:flutter/material.dart';
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:intl/intl.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await getIt<WhatsAppRepository>().getProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
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
      final exp = DateTime.parse(expiresAt.toString()).toLocal();
      final diff = exp.difference(DateTime.now()).inDays;
      if (diff < 0) return 'Expired';
      return '$diff days left';
    } catch (_) {
      return 'N/A';
    }
  }

  Color _expiryColor(dynamic expiresAt) {
    if (expiresAt == null) return Colors.grey;
    try {
      final exp = DateTime.parse(expiresAt.toString()).toLocal();
      final diff = exp.difference(DateTime.now()).inDays;
      if (diff < 0) return Colors.red;
      if (diff <= 7) return Colors.orange;
      return Colors.green;
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Failed to load profile'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        icon: Icons.person_outline,
                        title: 'Account Info',
                        children: [
                          _InfoTile('Name', _profile!['name']?.toString() ?? 'N/A'),
                          _InfoTile('Email', _profile!['email']?.toString() ?? 'N/A'),
                          _InfoTile('Member Since', _formatDate(_profile!['createdAt'])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSubscriptionSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    final sub = _profile?['subscription'];
    final pkg = _profile?['packageInfo'];

    if (sub == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'No active subscription',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final expiresAt = sub['expiresAt'] ?? sub['expiryDate'];
    final daysLeft = _daysLeft(expiresAt);
    final expiryColor = _expiryColor(expiresAt);

    return _buildSection(
      icon: Icons.workspace_premium,
      title: 'Subscription',
      children: [
        _InfoTile('Plan', pkg?['name']?.toString() ?? sub['packageName']?.toString() ?? 'N/A'),
        _InfoTile('Messages', '${sub['amount'] ?? pkg?['amount'] ?? 'N/A'}'),
        _InfoTile('Billing Cycle', _capitalize(sub['billingCycle']?.toString() ?? 'N/A')),
        _InfoTile('Price', '₹${sub['price'] ?? pkg?['price'] ?? 'N/A'}'),
        _InfoTile('Started', _formatDate(sub['startedAt'])),
        _InfoTile('Panel Expires', _formatDate(expiresAt)),
        _InfoTile('Credits Expire', _formatDate(sub['creditsExpiresAt'] ?? sub['creditsExpiryDate'])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: expiryColor.withValues(alpha: 0.1),
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
        if (pkg != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            pkg['description']?.toString() ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

