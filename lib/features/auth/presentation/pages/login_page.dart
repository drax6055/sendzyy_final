import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/dashboard/presentation/pages/dashboard_shell.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/register_page.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const ForgotPasswordDialog());
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginRequested(_emailController.text, _passwordController.text),
      );
    } else {
      // Trigger interactive card shake animation on validation error
      _shakeKey.currentState?.shake();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildWebBody(AuthState state) {
    return Stack(
      children: [
        // Full-screen background image
        Positioned.fill(
          child: Image.asset(
            'assets/images/home-bg-wp.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ShakeWidget(
                key: _shakeKey,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutBack,
                              builder: (context, val, child) {
                                return Transform.scale(scale: val, child: child);
                              },
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: 65,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          InteractiveTextField(
                            controller: _emailController,
                            hintText: 'Email Address',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              if (!value.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          InteractiveTextField(
                            controller: _passwordController,
                            hintText: 'Password',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showForgotPasswordDialog(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          InteractiveButton(
                            onPressed: _handleLogin,
                            isLoading: state is AuthLoading,
                            child: const Text(
                              'LOGIN',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text: "Don't have an account? ",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  children: const [
                                    TextSpan(
                                      text: 'Register',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(AuthState state) {
    return Stack(
      children: [
        // Full-screen background image matching web
        Positioned.fill(
          child: Image.asset(
            'assets/images/home-bg-wp.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ShakeWidget(
                key: _shakeKey,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 65,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 28),
                        InteractiveTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        InteractiveTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        InteractiveButton(
                          onPressed: _handleLogin,
                          isLoading: state is AuthLoading,
                          child: const Text(
                            'LOG IN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                children: const [
                                  TextSpan(
                                    text: 'Register',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardShell()),
          );
        } else if (state is AuthSubscriptionExpired) {
          _shakeKey.currentState?.shake();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 6),
            ),
          );
        } else if (state is AuthFailure) {
          // Trigger interactive shake animation on auth failure
          _shakeKey.currentState?.shake();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: kIsWeb ? _buildWebBody(state) : _buildMobileBody(state),
        );
      },
    );
  }
}

// Interactive custom Text Field with focus-glowing, validation feedback, and animated obscuring toggles
class InteractiveTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const InteractiveTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  State<InteractiveTextField> createState() => _InteractiveTextFieldState();
}

class _InteractiveTextFieldState extends State<InteractiveTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isObscured = true;
  bool _isValidEmail = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    
    if (!widget.isPassword) {
      widget.controller.addListener(_checkEmailValidation);
    }
  }

  void _checkEmailValidation() {
    final text = widget.controller.text;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      _isValidEmail = emailRegex.hasMatch(text);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (!widget.isPassword) {
      widget.controller.removeListener(_checkEmailValidation);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.isPassword && _isObscured,
        keyboardType: widget.keyboardType,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: _isFocused ? Colors.white : Colors.grey.shade50,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          prefixIcon: Icon(
            widget.prefixIcon,
            color: _isFocused ? AppTheme.primaryColor : Colors.grey.shade500,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      key: ValueKey<bool>(_isObscured),
                      color: _isFocused ? AppTheme.primaryColor : Colors.grey.shade500,
                    ),
                  ),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                )
              : (!widget.isPassword && _isValidEmail)
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: widget.validator,
      ),
    );
  }
}

// Premium button with scaling click-feedback animation
class InteractiveButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;

  const InteractiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
  });

  @override
  State<InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<InteractiveButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : widget.child,
        ),
      ),
    );
  }
}

// Physical feedback shaking container using a decaying sine wave
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double deltaX;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.deltaX = 12.0,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        if (progress == 0.0 || progress == 1.0) {
          return child!;
        }
        // Decaying horizontal shake sine wave
        final offset = widget.deltaX * math.sin(progress * math.pi * 4) * (1.0 - progress);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await getIt<WhatsAppRepository>().forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() { _loading = false; _sent = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: _sent ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
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
                child: const Icon(Icons.lock_reset_outlined, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Forgot Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your registered email address. We\'ll send you a new password.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          InteractiveTextField(
            controller: _emailCtrl,
            hintText: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          InteractiveButton(
            onPressed: _submit,
            isLoading: _loading,
            child: const Text('Send New Password',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_outlined,
              size: 40, color: Colors.green.shade600),
        ),
        const SizedBox(height: 20),
        const Text('Email Sent!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
          'A new password has been sent to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your inbox and log in with the new password. Change it immediately from Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Back to Login',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
