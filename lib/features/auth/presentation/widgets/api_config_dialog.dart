import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';

class ApiConfigDialog extends StatefulWidget {
  final String? initialWabaId;
  final String? initialPhoneNumberId;

  const ApiConfigDialog({
    super.key,
    this.initialWabaId,
    this.initialPhoneNumberId,
  });

  @override
  State<ApiConfigDialog> createState() => _ApiConfigDialogState();
}

class _ApiConfigDialogState extends State<ApiConfigDialog> {
  final _tokenController = TextEditingController();
  final _phoneIdController = TextEditingController();
  final _wabaIdController = TextEditingController();
  final _appIdController = TextEditingController();
  final _whatsappRepository = getIt<WhatsAppRepository>();
  bool _isLoading = false;

  static String get _fixedToken => AppConstants.metaAccessToken;
  static String get _fixedMetaAppId => AppConstants.metaAppId;

  @override
  void initState() {
    super.initState();
    _tokenController.text = _fixedToken;
    _appIdController.text = _fixedMetaAppId;

    // Pre-fill from embedded signup if provided
    if (widget.initialPhoneNumberId != null) {
      _phoneIdController.text = widget.initialPhoneNumberId!;
    }
    if (widget.initialWabaId != null) {
      _wabaIdController.text = widget.initialWabaId!;
    }

    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _whatsappRepository.getProfile();
      final config = profile['whatsappConfig'] ?? {};

      // Show the actual token from the server (may be the embedded signup token)
      final serverToken = config['accessToken']?.toString() ?? '';
      _tokenController.text = serverToken.isNotEmpty ? serverToken : _fixedToken;
      _appIdController.text = config['metaAppId']?.toString().isNotEmpty == true
          ? config['metaAppId'].toString()
          : _fixedMetaAppId;

      // Only overwrite if not already pre-filled from embedded signup
      if (widget.initialPhoneNumberId == null) {
        _phoneIdController.text = config['phoneNumberId'] ?? '';
      }
      if (widget.initialWabaId == null) {
        _wabaIdController.text = config['businessAccountId'] ?? '';
      }

      // If both IDs came from embedded signup, auto-save immediately
      if (widget.initialPhoneNumberId != null && widget.initialWabaId != null) {
        await _save(autoSave: true);
        return;
      }
    } catch (_) {
      // Keep prefilled values on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save({bool autoSave = false}) async {
    if (mounted) setState(() => _isLoading = true);

    // Use the token from the server profile if available (set by embedded signup),
    // otherwise fall back to the static platform token from .env
    String tokenToSave = _tokenController.text.trim();
    if (tokenToSave.isEmpty) {
      tokenToSave = _fixedToken;
    }

    final success = await _whatsappRepository.updateConfig(
      phoneNumberId: _phoneIdController.text.trim(),
      accessToken: tokenToSave,
      businessAccountId: _wabaIdController.text.trim(),
      metaAppId: _appIdController.text.trim().isNotEmpty ? _appIdController.text.trim() : _fixedMetaAppId,
    );
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else if (!autoSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update configuration')),
      );
    }
  }

  bool _isRegistering = false;

  Future<void> _triggerRegistration() async {
    setState(() => _isRegistering = true);
    try {
      final res = await _whatsappRepository.registerPhoneNumber();
      if (mounted) {
        setState(() => _isRegistering = false);
        if (res != null && res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Phone number registered successfully with Meta Cloud API! Status is now CONNECTED.')),
          );
        } else {
          final errDetail = res?['error'] ?? res?['details'] ?? 'Registration failed';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Registration Failed'),
              content: Text('Meta registration error: $errDetail'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Configuration'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                TextField(
                  controller: _tokenController,
                  maxLines: 3,
                  minLines: 1,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Permanent Access Token',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: const Tooltip(
                      message: 'This field is managed by the platform',
                      child: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneIdController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number ID',
                    hintText: 'e.g. 106543210987654',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _wabaIdController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Business Account ID',
                    hintText: 'e.g. 881145131296799',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _appIdController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Meta App ID (Required for Template Media)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: const Tooltip(
                      message: 'This field is managed by the platform',
                      child: Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isRegistering ? null : _triggerRegistration,
                  icon: _isRegistering 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_user_rounded, color: Colors.green),
                  label: Text(
                    _isRegistering ? 'Registering with Meta...' : 'Register Phone Number (Fix Error 141000)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: const Text('SAVE SETTINGS'),
        ),
      ],
    );
  }
}
