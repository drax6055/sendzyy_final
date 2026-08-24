import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';

class TestTemplateDialog extends StatefulWidget {
  final String templateName;
  final String languageCode;

  const TestTemplateDialog({
    super.key,
    required this.templateName,
    required this.languageCode,
  });

  @override
  State<TestTemplateDialog> createState() => _TestTemplateDialogState();
}

enum _Step { send, verify, verified }

class _TestTemplateDialogState extends State<TestTemplateDialog> {
  final _sendFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _Step _step = _Step.send;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_sendFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final success = await getIt<WhatsAppRepository>().sendOtp(
      to: _phoneController.text.trim(),
      templateName: widget.templateName,
      languageCode: widget.languageCode,
    );

    setState(() {
      _loading = false;
      if (success) {
        _step = _Step.verify;
      } else {
        _errorMessage = 'Failed to send OTP. Check the phone number and template status.';
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_verifyFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    final error = await getIt<WhatsAppRepository>().verifyOtp(
      to: _phoneController.text.trim(),
      otp: _otpController.text.trim(),
    );

    setState(() {
      _loading = false;
      if (error == null) {
        _step = _Step.verified;
      } else {
        _errorMessage = error;
      }
    });
  }

  void _reset() {
    _otpController.clear();
    setState(() { _step = _Step.send; _errorMessage = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.science_outlined, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Test Authentication Template',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Template badge
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 13, color: AppTheme.primaryColor),
                  const SizedBox(width: 5),
                  Text(
                    widget.templateName,
                    style: TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '  ·  ${widget.languageCode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StepIndicator(step: _step),
              const SizedBox(height: 24),
              if (_step == _Step.send) _buildSendStep(),
              if (_step == _Step.verify) _buildVerifyStep(),
              if (_step == _Step.verified) _buildVerifiedStep(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendStep() {
    return Form(
      key: _sendFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter phone number',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text('Include country code (e.g. +919876543210)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+91XXXXXXXXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Phone number is required';
              if (!RegExp(r'^\+\d{7,15}$').hasMatch(val.trim())) {
                return 'Enter a valid number with country code';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _ActionButton(loading: _loading, label: 'Send OTP on WhatsApp', icon: Icons.send_outlined, onPressed: _sendOtp),
        ],
      ),
    );
  }

  Widget _buildVerifyStep() {
    return Form(
      key: _verifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OTP sent to ${_phoneController.text.trim()}',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Enter the OTP',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('Check your WhatsApp for the 6-digit code',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(letterSpacing: 10, color: Colors.grey.shade400),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'OTP is required';
              if (val.trim().length != 6) return 'OTP must be 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _ActionButton(loading: _loading, label: 'Verify OTP', icon: Icons.verified_outlined, onPressed: _verifyOtp),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _reset,
              child: const Text('Change number / Resend', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 52),
              const SizedBox(height: 10),
              Text('OTP Verified',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              const SizedBox(height: 6),
              Text('The authentication template is working correctly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Test Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Step step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(label: '1  Send OTP', active: step == _Step.send, done: step != _Step.send),
        Expanded(child: Divider(color: step != _Step.send ? AppTheme.primaryColor : Colors.grey.shade300, thickness: 1.5)),
        _Dot(label: '2  Verify', active: step == _Step.verify, done: step == _Step.verified),
        Expanded(child: Divider(color: step == _Step.verified ? AppTheme.primaryColor : Colors.grey.shade300, thickness: 1.5)),
        _Dot(label: '3  Done', active: step == _Step.verified, done: false),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _Dot({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppTheme.primaryColor : Colors.grey.shade400;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? AppTheme.primaryColor : Colors.grey.shade200,
            border: Border.all(color: color, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : active
                  ? const Icon(Icons.circle, size: 9, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _ActionButton({required this.loading, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(loading ? 'Please wait...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }
}
