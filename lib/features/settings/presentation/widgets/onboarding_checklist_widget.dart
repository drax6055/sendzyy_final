import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:iFloraBuzz/core/utils/web_helper.dart';

class OnboardingChecklistWidget extends StatefulWidget {
  final VoidCallback? onSetupWhatsApp;
  final VoidCallback? onCreateTemplate;

  const OnboardingChecklistWidget({
    super.key,
    this.onSetupWhatsApp,
    this.onCreateTemplate,
  });

  @override
  State<OnboardingChecklistWidget> createState() => _OnboardingChecklistWidgetState();
}

class _OnboardingChecklistWidgetState extends State<OnboardingChecklistWidget> {
  bool _loading = true;
  bool _hasError = false;

  bool _whatsappConnected = false;
  bool _phoneVerified = false;
  String _metaBusinessVerified = 'NOT_VERIFIED'; // VERIFIED, PENDING, NOT_VERIFIED
  bool _hasApprovedTemplate = false;

  @override
  void initState() {
    super.initState();
    fetchStatus();
  }

  Future<void> fetchStatus() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final dio = getIt<Dio>();
      final resp = await dio.get('/onboarding-status');
      final data = resp.data;

      if (mounted) {
        setState(() {
          _whatsappConnected = data['whatsappConnected'] ?? false;
          _phoneVerified = data['phoneVerified'] ?? false;
          _metaBusinessVerified = data['metaBusinessVerified'] ?? 'NOT_VERIFIED';
          _hasApprovedTemplate = data['hasApprovedTemplate'] ?? false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  double get _progress {
    int completed = 0;
    if (_whatsappConnected) completed++;
    if (_phoneVerified) completed++;
    if (_metaBusinessVerified == 'VERIFIED') completed++;
    if (_hasApprovedTemplate) completed++;
    return completed / 4.0;
  }

  int get _completedStepsCount {
    int count = 0;
    if (_whatsappConnected) count++;
    if (_phoneVerified) count++;
    if (_metaBusinessVerified == 'VERIFIED') count++;
    if (_hasApprovedTemplate) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading onboarding checklist...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade100),
        ),
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Failed to load checklist status',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: fetchStatus,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final allStepsCompleted = _completedStepsCount == 4;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Progress Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WhatsApp Onboarding Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                      onPressed: fetchStatus,
                      tooltip: 'Refresh Status',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Follow these steps to fully activate your WhatsApp Business Account and launch message campaigns.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            allStepsCompleted ? Colors.green : AppTheme.primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$_completedStepsCount/4 Completed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: allStepsCompleted ? Colors.green : AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Steps list
          _buildStepRow(
            title: '1. Connect Meta Account via Embedded Signup',
            subtitle: 'Exchange permanent access token and resolve WABA account identifier.',
            isCompleted: _whatsappConnected,
            actionLabel: 'Connect Meta',
            onActionTap: widget.onSetupWhatsApp,
          ),
          const Divider(height: 1),

          _buildStepRow(
            title: '2. Register & Verify Phone Number',
            subtitle: 'Validate your phone ID with WhatsApp Business API setup.',
            isCompleted: _phoneVerified,
            isEnabled: _whatsappConnected,
            actionLabel: 'Configure ID',
            onActionTap: widget.onSetupWhatsApp,
          ),
          const Divider(height: 1),

          _buildStepRow(
            title: '3. Meta Business Verification',
            subtitle: _metaBusinessVerified == 'VERIFIED'
                ? 'Your Meta business profile is verified.'
                : (_metaBusinessVerified == 'PENDING'
                    ? 'Verification is pending Meta review. Templates will remain pending until approved.'
                    : 'Verify your business portfolio under Meta Settings to send templates at scale.'),
            isCompleted: _metaBusinessVerified == 'VERIFIED',
            isEnabled: _whatsappConnected,
            isWarning: _metaBusinessVerified == 'PENDING',
            actionLabel: 'Verify Business',
            onActionTap: () {
              webOpenUrl('https://business.facebook.com/settings/security');
            },
          ),
          const Divider(height: 1),

          _buildStepRow(
            title: '4. First Message Template Approved',
            subtitle: 'Meta must approve your templates. Avoid generic test strings to prevent auto-rejection.',
            isCompleted: _hasApprovedTemplate,
            isEnabled: _phoneVerified,
            actionLabel: 'Create Template',
            onActionTap: widget.onCreateTemplate,
          ),

          if (allStepsCompleted) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Setup Complete! You are ready to run automated and bulk marketing campaigns.',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isEnabled = true,
    bool isWarning = false,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    Color iconColor;
    IconData icon;

    if (isCompleted) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isWarning) {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange;
    } else {
      icon = Icons.radio_button_off;
      iconColor = isEnabled ? Colors.grey : Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isEnabled
                        ? (isCompleted ? Colors.black87 : Colors.black)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted && actionLabel != null && onActionTap != null && isEnabled) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onActionTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isWarning ? Colors.orange : AppTheme.primaryColor),
                foregroundColor: isWarning ? Colors.orange : AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
