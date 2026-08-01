import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'whatsapp_signup.dart';

extension type _SignupResult._(JSObject _) implements JSObject {
  external String get status;
  external String? get code;
  external String? get wabaId;
  external String? get phoneNumberId;
  external String? get sessionId;
  external String? get sessionInfoResponse;
  external String? get businessPortfolioId;
}

@JS('launchWhatsAppSignup')
external JSPromise<_SignupResult> _launchWhatsAppSignup(String appId, String configId);

/// Web implementation of launchWhatsAppSignupFlow.
Future<MetaSignupResult?> launchWhatsAppSignupFlow(String appId, String configId) async {
  try {
    final result = await _launchWhatsAppSignup(appId, configId).toDart;
    return MetaSignupResult(
      status: result.status,
      code: result.code,
      wabaId: result.wabaId,
      phoneNumberId: result.phoneNumberId,
      sessionId: result.sessionId,
      sessionInfoResponse: result.sessionInfoResponse,
      businessPortfolioId: result.businessPortfolioId,
    );
  } catch (e) {
    debugPrint('Error in launchWhatsAppSignupFlow: $e');
    return null;
  }
}

