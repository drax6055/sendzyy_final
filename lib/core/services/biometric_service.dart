import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Singleton service that wraps [LocalAuthentication] with platform guards
/// and structured error handling.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns `true` if the device supports biometrics AND the user has enrolled
  /// at least one biometric credential. Always returns `false` on web.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;

    try {
      // Hardware support check
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      // Enrolled biometrics check
      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the native biometric prompt.
  ///
  /// Returns a [BiometricResult] with [success] true if authentication passed,
  /// or [success] false with a human-readable [error] message otherwise.
  Future<BiometricResult> authenticate() async {
    if (kIsWeb) {
      return BiometricResult.failure('Biometrics are not supported on web.');
    }

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to log in to Sendzyy',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allows device PIN as fallback
        ),
      );

      return didAuthenticate
          ? BiometricResult.success()
          : BiometricResult.failure('Authentication was cancelled.');
    } on PlatformException catch (e) {
      return BiometricResult.failure(_humanReadableError(e));
    } catch (e) {
      return BiometricResult.failure('An unexpected error occurred.');
    }
  }

  String _humanReadableError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometrics are not available on this device.';
      case 'NotEnrolled':
        return 'No biometrics are enrolled. Please set up fingerprint or Face ID in Settings.';
      case 'LockedOut':
        return 'Too many failed attempts. Biometrics are temporarily locked.';
      case 'PermanentlyLockedOut':
        return 'Biometrics are permanently locked. Use your PIN to unlock the device.';
      case 'PasscodeNotSet':
        return 'No device passcode set. Please set up a passcode in Settings.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

/// Result type for biometric authentication attempts.
class BiometricResult {
  final bool success;
  final String? error;

  const BiometricResult._({required this.success, this.error});

  factory BiometricResult.success() => const BiometricResult._(success: true);
  factory BiometricResult.failure(String message) =>
      BiometricResult._(success: false, error: message);
}
