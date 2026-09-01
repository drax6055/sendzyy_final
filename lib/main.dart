import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/messages/presentation/bloc/message_bloc.dart';
import 'package:iFloraBuzz/features/reports/presentation/bloc/report_bloc.dart';
import 'core/di/injection.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/package_selection_page.dart';
import 'features/dashboard/presentation/pages/dashboard_shell.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'features/chat/data/services/socket_service.dart';
import 'package:iFloraBuzz/features/admin/presentation/pages/update_message_page.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';

import 'package:iFloraBuzz/features/calling/presentation/pages/active_call_page.dart';
import 'package:iFloraBuzz/features/calling/presentation/pages/call_log_page.dart';
import 'package:iFloraBuzz/features/calling/presentation/pages/calling_settings_page.dart';
import 'package:iFloraBuzz/features/calling/presentation/pages/call_permission_page.dart';
import 'package:iFloraBuzz/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_control_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_log_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_settings_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_permission_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:iFloraBuzz/features/notifications/data/datasources/fcm_service.dart';
import 'firebase_options.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_bloc.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_event.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_state.dart';
import 'package:iFloraBuzz/features/app_update/presentation/widgets/app_update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[FCM] Firebase initialization notice: $e');
  }
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _expiryTimer;
  late final AuthBloc _authBloc;
  StreamSubscription<String>? _systemUpdateSubscription;
  bool _isUpdateDialogShowing = false;

  @override
  void initState() {
    super.initState();
    setupWebBeforeUnload();
    _authBloc = di.getIt<AuthBloc>()..add(AuthCheckRequested());
    _handleInstagramCallback();

    // Check subscription expiry every 5 minutes while app is running
    _expiryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _authBloc.add(SubscriptionExpiryCheckRequested());
    });

    _systemUpdateSubscription = di.getIt<SocketService>().systemUpdateStream.listen((message) {
      _showUpdateAlertDialog(message);
    });
  }

  void _handleInstagramCallback() {
    try {
      final uri = Uri.base;
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];
      final instagramConnected = uri.queryParameters['instagram_connected'];

      if (code != null && state != null) {
        // Instagram redirected here with code — bounce to backend callback
        final backendUrl = dotenv.env['BASE_URL'] ?? '';
        final frontendUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';

        final callbackUrl = '$backendUrl/api/instagram/callback'
            '?code=$code'
            '&state=$state'
            '&frontend_url=${Uri.encodeComponent(frontendUrl)}';

        webRedirect(callbackUrl);

      } else if (instagramConnected == 'true') {
        // Backend completed OAuth successfully — clean URL and show success
        webClearUrlQueryParams('Sendzyy');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Instagram connected successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        });

      } else if (error != null) {
        // Clear query parameters from address bar
        webClearUrlQueryParams('Sendzyy');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Instagram connection failed: $error',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling Instagram callback: $e');
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _systemUpdateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(
          create: (context) => di.getIt<TemplateBloc>(),
        ),
        BlocProvider(create: (context) => di.getIt<MessageBloc>()),
        BlocProvider(
          create: (context) =>
              di.getIt<ReportBloc>()..add(FetchReportHistory()),
        ),
        BlocProvider(create: (context) => di.getIt<NotificationBloc>()),
        BlocProvider.value(value: di.getIt<CallControlBloc>()),
        BlocProvider.value(value: di.getIt<CallLogBloc>()),
        BlocProvider(create: (context) => di.getIt<CallSettingsBloc>()),
        BlocProvider(create: (context) => di.getIt<CallPermissionBloc>()),
        BlocProvider(
          create: (context) =>
              di.getIt<AppUpdateBloc>()..add(const CheckForUpdateEvent()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Sendzyy',
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return BlocListener<AppUpdateBloc, AppUpdateState>(
            listener: (context, updateState) {
              if (updateState is AppUpdateAvailable && !_isUpdateDialogShowing) {
                _isUpdateDialogShowing = true;
                final navContext = navigatorKey.currentContext ?? context;
                AppUpdateDialog.show(
                  navContext,
                  updateInfo: updateState.updateInfo,
                  currentVersion: updateState.currentVersion,
                  currentBuildNumber: updateState.currentBuildNumber,
                ).then((_) {
                  _isUpdateDialogShowing = false;
                });
              }
            },
            child: child ?? const SizedBox.shrink(),
          );
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/update_message' || settings.name == 'update_message') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const UpdateMessagePage(),
            );
          }
          if (settings.name == '/calling/active' || settings.name == 'calling_active') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const ActiveCallPage(),
            );
          }
          if (settings.name == '/calling/log' || settings.name == 'calling_log') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const CallLogPage(),
            );
          }
          if (settings.name == '/calling/settings' || settings.name == 'calling_settings') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => CallingSettingsPage(
                phoneNumberId: args?['phoneNumberId'] ?? '',
              ),
            );
          }
          if (settings.name == '/calling/permissions' || settings.name == 'calling_permissions') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => CallPermissionPage(
                phoneNumberId: args?['phoneNumberId'] ?? '',
                userWaId: args?['userWaId'] ?? '',
              ),
            );
          }
          return null;
        },
        home: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              // Immediately check expiry on login/app start
              _authBloc.add(SubscriptionExpiryCheckRequested());
              // Re-fetch templates now that we have a valid auth token
              context.read<TemplateBloc>().add(FetchTemplates());

              final tenantId = state.tenant['id']?.toString() ??
                  state.tenant['_id']?.toString() ??
                  '';
              if (tenantId.isNotEmpty) {
                context.read<NotificationBloc>().add(
                      RefreshUnreadCountEvent(tenantId: tenantId),
                    );
              }
            }
            if (state is AuthSubscriptionExpired) {
              // Show expiry dialog on top of whatever screen is showing
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showExpiredDialog(context, state.message);
              });
            }
          },
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const DashboardShell();
            }
            if (state is AuthLoading || state is AuthInitial) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }

  void _showExpiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Subscription Expired'),
          ],
        ),
        content: Text(message),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Go to Login',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _showRenewCredentialsDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Renew Package',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenewCredentialsDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Your Identity'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your credentials to proceed with renewal.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final email = emailCtrl.text.trim();
                final password = passCtrl.text;
                Navigator.of(ctx).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PackageSelectionPage(
                      renewEmail: email,
                      renewPassword: password,
                    ),
                  ),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUpdateAlertDialog(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                      child: Column(
                        children: [
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
                          const Text(
                            'System Update Required',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A4D4F),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE4E6EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF075E54),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your session will be cleared and the app will reload to ensure a smooth transition.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF075E54).withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                _authBloc.add(LogoutRequested());
                                Navigator.of(dialogCtx).pop();
                                webClearStorageAndReload();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'OK, Refresh Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
