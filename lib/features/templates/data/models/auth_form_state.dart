import 'app_entry.dart';

class AuthFormState {
  final String codeDeliveryType; // 'ZERO_TAP' | 'ONE_TAP' | 'COPY_CODE'
  final bool zeroTapTosAccepted;
  final List<AppEntry> appEntries;
  final bool addSecurityRecommendation; // default true
  final bool addExpiryTime; // default false
  final int? codeExpirationMinutes;
  final bool validityEnabled; // default true for auth
  final int validitySeconds; // default 600 (10 min)

  const AuthFormState({
    this.codeDeliveryType = 'ZERO_TAP',
    this.zeroTapTosAccepted = false,
    this.appEntries = const [AppEntry(packageName: '', signatureHash: '')],
    this.addSecurityRecommendation = true,
    this.addExpiryTime = false,
    this.codeExpirationMinutes,
    this.validityEnabled = true,
    this.validitySeconds = 600,
  });

  AuthFormState copyWith({
    String? codeDeliveryType,
    bool? zeroTapTosAccepted,
    List<AppEntry>? appEntries,
    bool? addSecurityRecommendation,
    bool? addExpiryTime,
    int? codeExpirationMinutes,
    bool? validityEnabled,
    int? validitySeconds,
    bool clearCodeExpirationMinutes = false,
  }) {
    return AuthFormState(
      codeDeliveryType: codeDeliveryType ?? this.codeDeliveryType,
      zeroTapTosAccepted: zeroTapTosAccepted ?? this.zeroTapTosAccepted,
      appEntries: appEntries ?? this.appEntries,
      addSecurityRecommendation:
          addSecurityRecommendation ?? this.addSecurityRecommendation,
      addExpiryTime: addExpiryTime ?? this.addExpiryTime,
      codeExpirationMinutes: clearCodeExpirationMinutes
          ? null
          : (codeExpirationMinutes ?? this.codeExpirationMinutes),
      validityEnabled: validityEnabled ?? this.validityEnabled,
      validitySeconds: validitySeconds ?? this.validitySeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFormState &&
          runtimeType == other.runtimeType &&
          codeDeliveryType == other.codeDeliveryType &&
          zeroTapTosAccepted == other.zeroTapTosAccepted &&
          appEntries == other.appEntries &&
          addSecurityRecommendation == other.addSecurityRecommendation &&
          addExpiryTime == other.addExpiryTime &&
          codeExpirationMinutes == other.codeExpirationMinutes &&
          validityEnabled == other.validityEnabled &&
          validitySeconds == other.validitySeconds;

  @override
  int get hashCode =>
      codeDeliveryType.hashCode ^
      zeroTapTosAccepted.hashCode ^
      appEntries.hashCode ^
      addSecurityRecommendation.hashCode ^
      addExpiryTime.hashCode ^
      codeExpirationMinutes.hashCode ^
      validityEnabled.hashCode ^
      validitySeconds.hashCode;

  @override
  String toString() => 'AuthFormState('
      'codeDeliveryType: $codeDeliveryType, '
      'zeroTapTosAccepted: $zeroTapTosAccepted, '
      'appEntries: $appEntries, '
      'addSecurityRecommendation: $addSecurityRecommendation, '
      'addExpiryTime: $addExpiryTime, '
      'codeExpirationMinutes: $codeExpirationMinutes, '
      'validityEnabled: $validityEnabled, '
      'validitySeconds: $validitySeconds)';
}

