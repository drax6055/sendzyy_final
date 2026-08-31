import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing authentication credentials in the device's
/// secure enclave (Keychain on iOS, EncryptedSharedPreferences on Android).
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

  /// Persist credentials after a successful email/password login.
  Future<void> saveCredentials({
    required String token,
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kEnabled, value: 'true');
  }

  /// Read credentials previously saved by [saveCredentials].
  /// Returns `null` if credentials have not been stored yet.
  Future<StoredCredentials?> loadCredentials() async {
    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPassword);
    final token = await _storage.read(key: _kToken);
    final enabled = await _storage.read(key: _kEnabled);

    if (email == null || password == null || enabled != 'true') return null;
    return StoredCredentials(email: email, password: password, token: token);
  }

  /// Returns `true` if credentials are stored and biometric login is enabled.
  Future<bool> hasSavedCredentials() async {
    final enabled = await _storage.read(key: _kEnabled);
    if (enabled != 'true') return false;
    final email = await _storage.read(key: _kEmail);
    return email != null;
  }

  /// Delete all stored credentials — call on logout.
  Future<void> clearCredentials() async {
    await _storage.deleteAll();
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
