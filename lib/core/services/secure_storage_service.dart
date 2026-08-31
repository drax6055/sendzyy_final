import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing authentication credentials in the device's
/// secure enclave (Keychain on iOS, EncryptedSharedPreferences on Android).
/// Safe on Web & non-secure contexts (gracefully no-ops).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _kToken = 'bio_auth_token';
  static const _kEmail = 'bio_auth_email';
  static const _kPassword = 'bio_auth_password';
  static const _kEnabled = 'bio_auth_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Persist credentials after a successful email/password login (mobile only).
  Future<void> saveCredentials({
    required String token,
    required String email,
    required String password,
  }) async {
    if (kIsWeb) return;
    try {
      await _storage.write(key: _kToken, value: token);
      await _storage.write(key: _kEmail, value: email);
      await _storage.write(key: _kPassword, value: password);
      await _storage.write(key: _kEnabled, value: 'true');
    } catch (e) {
      debugPrint('[SecureStorage] saveCredentials warning: $e');
    }
  }

  /// Read credentials previously saved by [saveCredentials].
  /// Returns `null` if on web or credentials have not been stored yet.
  Future<StoredCredentials?> loadCredentials() async {
    if (kIsWeb) return null;
    try {
      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);
      final token = await _storage.read(key: _kToken);
      final enabled = await _storage.read(key: _kEnabled);

      if (email == null || password == null || enabled != 'true') return null;
      return StoredCredentials(email: email, password: password, token: token);
    } catch (e) {
      debugPrint('[SecureStorage] loadCredentials warning: $e');
      return null;
    }
  }

  /// Returns `true` if credentials are stored and biometric login is enabled.
  Future<bool> hasSavedCredentials() async {
    if (kIsWeb) return false;
    try {
      final enabled = await _storage.read(key: _kEnabled);
      if (enabled != 'true') return false;
      final email = await _storage.read(key: _kEmail);
      return email != null;
    } catch (e) {
      debugPrint('[SecureStorage] hasSavedCredentials warning: $e');
      return false;
    }
  }

  /// Delete all stored credentials — call on logout.
  Future<void> clearCredentials() async {
    if (kIsWeb) return;
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SecureStorage] clearCredentials warning: $e');
    }
  }
}

/// Data class holding decrypted credentials read from secure storage.
class StoredCredentials {
  final String email;
  final String password;
  final String? token;

  const StoredCredentials({
    required this.email,
    required this.password,
    this.token,
  });
}
