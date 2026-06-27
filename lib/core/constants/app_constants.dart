import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'iFloraBuzz';

  // Secrets loaded from .env
  static String get metaAccessToken =>
      dotenv.env['META_ACCESS_TOKEN'] ?? '';
  static String get metaAppId => dotenv.env['META_APP_ID'] ?? '';

  // Local BASEURL-----------------------------------------------------
  
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';




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
