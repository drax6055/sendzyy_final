import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/core/di/injection.dart';

/// Shows an "Enter Password" modal dialog to verify user identity before performing protected actions.
/// Returns `true` if password is verified successfully, `false` otherwise.
Future<bool> showPasswordVerificationDialog(
  BuildContext context, {
  String prompt = 'Enter your login password to perform this action.',
}) async {
  final passwordController = TextEditingController();
  bool obscure = true;
  String? error;
  bool verifying = false;

  final bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Future<void> verify() async {
          final password = passwordController.text.trim();
          if (password.isEmpty) {
            setDialogState(() => error = 'Please enter your password');
            return;
          }
          setDialogState(() {
            verifying = true;
            error = null;
          });
          try {
            final prefs = await SharedPreferences.getInstance();
            final tenantJson = prefs.getString('tenant_data');
            final email = tenantJson != null
                ? (jsonDecode(tenantJson) as Map<String, dynamic>)['email']?.toString() ?? ''
                : '';

            if (email.isEmpty) {
              setDialogState(() {
                verifying = false;
                error = 'Could not retrieve account info';
              });
              return;
            }

            final dio = getIt<Dio>();
            final res = await dio.post('/login', data: {'email': email, 'password': password});
            if (res.statusCode == 200) {
              if (ctx.mounted) Navigator.pop(ctx, true);
            } else {
              setDialogState(() {
                verifying = false;
                error = 'Incorrect password';
              });
            }
          } on DioException catch (e) {
            final msg = e.response?.data?['error']?.toString() ?? 'Incorrect password';
            setDialogState(() {
              verifying = false;
              error = msg;
            });
          } catch (_) {
            setDialogState(() {
              verifying = false;
              error = 'Verification failed. Try again.';
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_rounded, color: AppTheme.secondaryColor, size: 22),
              const SizedBox(width: 8),
              const Text('Enter Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prompt,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                autofocus: true,
                enabled: !verifying,
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: error,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) => verify(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: verifying ? null : verify,
              child: verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Unlock'),
            ),
          ],
        );
      },
    ),
  );

  return result ?? false;
}

