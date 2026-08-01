export 'whatsapp_signup_stub.dart'
    if (dart.library.html) 'whatsapp_signup_web.dart';

class MetaSignupResult {
  final String status;
  final String? code;
  final String? wabaId;
  final String? phoneNumberId;
  final String? sessionId;
  final String? sessionInfoResponse;
  final String? businessPortfolioId;

  MetaSignupResult({
    required this.status,
    this.code,
    this.wabaId,
    this.phoneNumberId,
    this.sessionId,
    this.sessionInfoResponse,
    this.businessPortfolioId,
  });
}

