import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  BiometricAuthResult.success() : succeeded = true, message = null;
  BiometricAuthResult.failure(this.message) : succeeded = false;

  final bool succeeded;
  final String? message;
}

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Gates enrollment and mark-in behind the device's own Face ID/fingerprint
  /// sensor specifically — biometricOnly:true so a device PIN/pattern can't
  /// substitute for it (a PIN is far easier for a second person to obtain
  /// than to fake someone else's enrolled fingerprint). See
  /// AttendanceController::markIn()/enrollBiometric() for how this maps
  /// server-side.
  Future<bool> authenticate({String reason = "Confirm it's you to mark attendance"}) async {
    final result = await authenticateWithDetail(reason: reason);
    return result.succeeded;
  }

  /// Same as [authenticate] but with a human-readable reason on failure —
  /// used by the enrollment screen, where "no fingerprint enrolled on this
  /// phone" deserves a different message than "you cancelled."
  Future<BiometricAuthResult> authenticateWithDetail({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricAuthResult.success() : BiometricAuthResult.failure('Verification was cancelled.');
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotEnrolled':
          return BiometricAuthResult.failure('No fingerprint or face is set up on this phone yet — add one in your device Settings, then try again.');
        case 'NotAvailable':
          return BiometricAuthResult.failure('This device does not support fingerprint or face verification.');
        case 'LockedOut':
          return BiometricAuthResult.failure('Too many failed attempts. Please wait a moment and try again.');
        case 'PermanentlyLockedOut':
          return BiometricAuthResult.failure('Biometric verification is locked. Unlock your phone with its PIN/pattern first, then try again.');
        case 'PasscodeNotSet':
          return BiometricAuthResult.failure('Please set up a screen lock on this phone before registering your fingerprint.');
        default:
          return BiometricAuthResult.failure('Verification failed. Please try again.');
      }
    } catch (_) {
      return BiometricAuthResult.failure('Verification failed. Please try again.');
    }
  }
}
