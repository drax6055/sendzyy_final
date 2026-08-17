// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

extension type _SignupResult._(JSObject _) implements JSObject {
  external String get status;
  external String? get code;
  external String? get wabaId;
  external String? get phoneNumberId;
  external String? get sessionId;
  external String? get sessionInfoResponse;
  external String? get businessPortfolioId;
}

@JS()
external JSPromise<_SignupResult> launchWhatsAppSignup(
  String appId,
  String configId,
);

Future<Map<String, dynamic>?> triggerMetaSignup(String appId, String configId) async {
  try {
    final result = await launchWhatsAppSignup(appId, configId).toDart;
    return {
      'status': result.status,
      'code': result.code,
      'wabaId': result.wabaId,
      'phoneNumberId': result.phoneNumberId,
      'sessionId': result.sessionId,
      'sessionInfoResponse': result.sessionInfoResponse,
      'businessPortfolioId': result.businessPortfolioId,
    };
  } catch (e) {
    return null;
  }
}
