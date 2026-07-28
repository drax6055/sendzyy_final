import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/di/injection.dart';


class UpdateMessagePage extends StatefulWidget {
  const UpdateMessagePage({super.key});

  @override
  State<UpdateMessagePage> createState() => _UpdateMessagePageState();
}

class _UpdateMessagePageState extends State<UpdateMessagePage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final String _secretKey = 'sendzyy-update-secret-9988';
  
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final dio = getIt<Dio>();
      final response = await dio.post(
        '/api/admin/system-update',
        data: {
          'secret': _secretKey,
          'message': _messageController.text.trim(),
        },
      );

      setState(() {
        _isLoading = false;
        _isSuccess = response.data['success'] ?? false;
        _statusMessage = response.data['message'] ?? 'Broadcast sent successfully!';
      });
      
      if (_isSuccess) {
        _messageController.clear();
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? 'Failed to send broadcast. Check network connection.';
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = errorMsg.toString();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Styled Container (Main Form Card)
              Container(
                constraints: const BoxConstraints(maxWidth: 550),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Green Accent Bar
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF25D366),
                              Color(0xFF128C7E),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(36),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Circular Update Icon Container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.security_update_good_rounded,
                                  color: Color(0xFF128C7E),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Title & Subtitle
                              const Text(
                                'Trigger System Update Alert',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1D1E),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Deploy a real-time update notice to all active tenants. This clears browser caches forcefully and initiates user force-logout.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4A4D4F),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Secret Field (Locked and not editable)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Secret Key (System Locked)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1D1E).withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: _secretKey,
                                readOnly: true,
                                style: const TextStyle(
                                  color: Color(0xFF8A8D8F),
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8A8D8F)),
                                  fillColor: const Color(0xFFF5F6F7),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4E6EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4E6EB)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Message Field
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Broadcast Message',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1D1E).withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _messageController,
                                minLines: 4,
                                maxLines: 6,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter the update message to broadcast';
                                  }
                                  return null;
                                },
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1D1E),
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Our software will undergo scheduled maintenance tomorrow, 04/07/2026, from 11:00 AM to (approximately 10 minutes), during which the service may be temporarily unavailable...',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF8A8D8F).withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4E6EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4E6EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF25D366), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    disabledBackgroundColor: const Color(0xFF25D366).withValues(alpha: 0.5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Broadcast System Alert',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),

                              // Status Message Container
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _isSuccess
                                        ? const Color(0xFFE8F8F0)
                                        : const Color(0xFFFDECEB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _isSuccess
                                          ? const Color(0xFFB3E8CC)
                                          : const Color(0xFFF9C0C0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isSuccess
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.error_outline_rounded,
                                        color: _isSuccess
                                            ? const Color(0xFF0F7D43)
                                            : const Color(0xFFD63031),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _statusMessage!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _isSuccess
                                                ? const Color(0xFF0F7D43)
                                                : const Color(0xFFD63031),
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
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
      ),
    );
  }
}
