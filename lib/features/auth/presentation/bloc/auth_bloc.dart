import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
  @override
  List<Object> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  RegisterRequested(this.name, this.email, this.password);
  @override
  List<Object> get props => [name, email, password];
}

class AuthCheckRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

/// Fired periodically or on API 403 to force-logout expired sessions
class SubscriptionExpiryCheckRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String user;
  final Map<String, dynamic> tenant;
  AuthAuthenticated(this.user, this.tenant);
  @override
  List<Object> get props => [user, tenant];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
  @override
  List<Object> get props => [message];
}

class AuthSubscriptionExpired extends AuthState {
  final String message;
  AuthSubscriptionExpired(this.message);
  @override
  List<Object> get props => [message];
}

class AuthAccountInactive extends AuthState {
  final String message;
  AuthAccountInactive(this.message);
  @override
  List<Object> get props => [message];
}

class AuthRegistered extends AuthState {
  final String regToken;
  AuthRegistered(this.regToken);
  @override
  List<Object> get props => [regToken];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SharedPreferences _prefs;
  final Dio _dio;
  final SocketService _socketService;
  static const String _keyToken = 'auth_token';

  AuthBloc(this._prefs, this._dio, this._socketService) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      final token = _prefs.getString(_keyToken);
      if (token == null) {
        emit(AuthUnauthenticated());
        return;
      }

      // Always re-fetch from server to get the latest whatsappConfig after embedded signup
      try {
        final response = await _dio.get('/me');
        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          // Build a tenant map compatible with what login returns
          final tenant = {
            'id': data['id'],
            'name': data['name'],
            'email': data['email'],
            'subscription': data['subscription'],
            'whatsappConfig': data['whatsappConfig'],
          };

          await _prefs.setString('tenant_data', jsonEncode(tenant));

          final config = tenant['whatsappConfig'] ?? {};
          if (config['accessToken'] != null) {
            await _prefs.setString(AppConstants.keyAccessToken, config['accessToken']);
          }
          if (config['phoneNumberId'] != null) {
            await _prefs.setString(AppConstants.keyPhoneNumberId, config['phoneNumberId']);
          }
          if (config['businessAccountId'] != null) {
            await _prefs.setString(AppConstants.keyWabaId, config['businessAccountId']);
          }
          if (config['metaAppId'] != null) {
            await _prefs.setString(AppConstants.keyAppId, config['metaAppId']);
          }

          _socketService.connect(tenant['id'], token, AppConstants.baseUrl);
          emit(AuthAuthenticated(tenant['name'] as String, tenant));
          return;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          await _clearSession();
          emit(AuthUnauthenticated());
          return;
        }
        // Network error — fall back to cached data so the user stays logged in offline
      } catch (_) {
        // Fall back to cache on unexpected errors
      }

      // Fallback: use cached tenant_data (e.g. offline)
      final tenantJson = _prefs.getString('tenant_data');
      if (tenantJson != null) {
        final tenant = jsonDecode(tenantJson) as Map<String, dynamic>;
        final config = tenant['whatsappConfig'] ?? {};
        if (config['accessToken'] != null) {
          await _prefs.setString(AppConstants.keyAccessToken, config['accessToken']);
        }
        if (config['phoneNumberId'] != null) {
          await _prefs.setString(AppConstants.keyPhoneNumberId, config['phoneNumberId']);
        }
        if (config['businessAccountId'] != null) {
          await _prefs.setString(AppConstants.keyWabaId, config['businessAccountId']);
        }
        if (config['metaAppId'] != null) {
          await _prefs.setString(AppConstants.keyAppId, config['metaAppId']);
        }
        _socketService.connect(tenant['id'], token, AppConstants.baseUrl);
        emit(AuthAuthenticated(tenant['name'] as String, tenant));
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await _dio.post('/login', data: {
          'email': event.email.trim().toLowerCase(),
          'password': event.password,
        });

        if (response.statusCode == 200) {
          final token = response.data['token'];
          final tenant = response.data['tenant'];

          await _prefs.setString(_keyToken, token);
          await _prefs.setString('tenant_id', tenant['id']);
          await _prefs.setString('tenant_data', jsonEncode(tenant));

          // Sync API credentials to SharedPreferences for media upload and template operations
          final config = tenant['whatsappConfig'] ?? {};
          if (config['accessToken'] != null) {
            await _prefs.setString(AppConstants.keyAccessToken, config['accessToken']);
          }
          if (config['phoneNumberId'] != null) {
            await _prefs.setString(AppConstants.keyPhoneNumberId, config['phoneNumberId']);
          }
          if (config['businessAccountId'] != null) {
            await _prefs.setString(AppConstants.keyWabaId, config['businessAccountId']);
          }
          if (config['metaAppId'] != null) {
            await _prefs.setString(AppConstants.keyAppId, config['metaAppId']);
          }

          _socketService.connect(tenant['id'], token, AppConstants.baseUrl);
          emit(AuthAuthenticated(tenant['name'], tenant));
        } else {
          emit(AuthFailure(response.data['error'] ?? 'Login failed'));
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          final errCode = e.response?.data?['error'];
          if (errCode == 'subscription_expired') {
            emit(AuthSubscriptionExpired(
              e.response?.data?['message'] ??
                  'Your subscription has expired. Please renew your plan.',
            ));
            return;
          }
          if (errCode == 'account_inactive') {
            emit(AuthAccountInactive(
              e.response?.data?['message'] ??
                  'Your account is inactive. Please contact support.',
            ));
            return;
          }
          if (errCode == 'no_subscription') {
            emit(AuthFailure(
              e.response?.data?['message'] ??
                  'No active subscription. Please complete your plan purchase.',
            ));
            return;
          }
        }
        emit(AuthFailure('Connection error: $e'));
      } catch (e) {
        emit(AuthFailure('Connection error: $e'));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await _dio.post('/register', data: {
          'name': event.name,
          'email': event.email.trim().toLowerCase(),
          'password': event.password,
        });

        if (response.statusCode == 201) {
          emit(AuthRegistered(response.data['regToken'] as String));
        } else {
          emit(AuthFailure(response.data['error'] ?? 'Registration failed'));
        }
      } catch (e) {
        emit(AuthFailure('Connection error: $e'));
      }
    });

    on<LogoutRequested>((event, emit) async {
      await _clearSession();
      emit(AuthUnauthenticated());
    });

    on<SubscriptionExpiryCheckRequested>((event, emit) async {
      if (state is! AuthAuthenticated) return;
      try {
        final response = await _dio.get('/me');
        if (response.statusCode == 200) {
          final sub = response.data['subscription'];
          // Support both expiresAt (functions server) and expiryDate (webhook server)
          final expiryRaw = sub?['expiresAt'] ?? sub?['expiryDate'];
          if (expiryRaw != null) {
            final expiresAt = DateTime.tryParse(expiryRaw.toString());
            if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
              await _clearSession();
              emit(AuthSubscriptionExpired(
                'Your subscription expired on ${_formatDate(expiresAt)}. Please renew to continue.',
              ));
            }
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          final errCode = e.response?.data?['error'];
          if (errCode == 'subscription_expired') {
            await _clearSession();
            emit(AuthSubscriptionExpired(
              e.response?.data?['message'] ?? 'Your subscription has expired.',
            ));
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _clearSession() async {
    _socketService.disconnect();
    await _prefs.remove(_keyToken);
    await _prefs.remove('tenant_id');
    await _prefs.remove('tenant_data');
    await _prefs.remove('access_token');
    await _prefs.remove('phone_number_id');
    await _prefs.remove('waba_id');
    await _prefs.remove('meta_app_id');
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
