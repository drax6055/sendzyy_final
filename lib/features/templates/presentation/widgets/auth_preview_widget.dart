import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/templates/data/models/auth_form_state.dart';

class AuthPreviewWidget extends StatelessWidget {
  final AuthFormState state;

  const AuthPreviewWidget({super.key, required this.state});

  String _buildBodyText() {
    final buffer = StringBuffer('[{{1}}] is your verification code.');
    if (state.addSecurityRecommendation) {
      buffer.write(' For your security, do not share this code.');
    }
    if (state.addExpiryTime && state.codeExpirationMinutes != null) {
      buffer.write(' This code expires in ${state.codeExpirationMinutes} minutes.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5DDD5),
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage(
            'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
          ),
          opacity: 0.1,
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.videocam, color: Colors.white, size: 20),
                SizedBox(width: 16),
                Icon(Icons.call, color: Colors.white, size: 20),
                SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [_buildMessageBubble()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                _buildBodyText(),
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                '11:59',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
            if (state.codeDeliveryType != 'ZERO_TAP') ...[
              const Divider(height: 1),
              _buildOtpButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtpButton() {
    // ZERO_TAP auto-fills silently — no button shown in preview
    if (state.codeDeliveryType == 'ZERO_TAP') return const SizedBox.shrink();

    final isCopyCode = state.codeDeliveryType == 'COPY_CODE';
    final label = isCopyCode ? 'Copy code' : _autofillLabel();
    final icon = isCopyCode ? Icons.copy_outlined : Icons.flash_on_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00a5f4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF00a5f4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _autofillLabel() {
    if (state.appEntries.isNotEmpty) {
      final packageName = state.appEntries.first.packageName;
      if (packageName.isNotEmpty) return packageName;
    }
    return 'Autofill';
  }
}
