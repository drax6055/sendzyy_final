import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sendzyy/core/constants/app_constants.dart';
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/features/templates/data/models/assistant_exception.dart';
import 'package:sendzyy/features/templates/data/models/generated_template.dart';

class TemplateAssistantService {
  final Dio _dio = getIt<Dio>();

  Future<GeneratedTemplate> generateTemplate(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getString(AppConstants.keyTenantId) ?? '';

    try {
      final response = await _dio.post(
        '/api/ai/generate-template',
        data: {'tenantId': tenantId, 'prompt': prompt},
      );
      return GeneratedTemplate.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = _extractMessage(e);

      if (statusCode == 422) {
        throw AssistantException(message, isKeyNotConfigured: true);
      }
      throw AssistantException(message);
    } catch (e) {
      throw AssistantException(e.toString());
    }
  }

  String _extractMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'] as String;
      }
      if (data is Map<String, dynamic> && data['error'] != null) {
        return data['error'] as String;
      }
    } catch (_) {}
    return e.message ?? 'An unexpected error occurred';
  }
}

