import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Sendzyy';

  static const String metaGraphUrl = 'https://graph.facebook.com/v25.0';

  // Secrets loaded from .env
  static String get metaAccessToken => dotenv.env['META_ACCESS_TOKEN'] ?? '';

  static String get metaAppId {
    final value = dotenv.env['META_APP_ID'] ?? '';
    if (value.isEmpty || value == '1241458147867376') {
      return '1509853364110343';
    }
    return value;
  }

  static String get metaConfigId {
    final value = dotenv.env['META_CONFIG_ID'] ?? '';
    if (value.isEmpty) {
      return '1468906758584325';
    }
    return value;
  }

  static String get baseUrl {
    final url = dotenv.env['BASE_URL'] ?? '';
    if (url.isEmpty) {
      return 'https://appapi.sendzyy.com';
    }
    return url;
  }

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyPhoneNumberId = 'phone_number_id';
  static const String keyWabaId = 'waba_id';
  static const String keyAppId = 'meta_app_id';
  static const String keyCredits = 'user_credits';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyTenantId = 'tenant_id';
  static const String keyCampaigns = 'campaign_history';
}

