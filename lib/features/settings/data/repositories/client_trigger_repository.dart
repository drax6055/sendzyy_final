import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/settings/data/models/client_trigger_model.dart';

class ClientTriggerRepository {
  final Dio _dio;

  ClientTriggerRepository(this._dio);

  /// Fetch the current tenant's trigger. Returns null if none exists (404).
  Future<ClientTriggerModel?> fetchTrigger() async {
    try {
      final response = await _dio.get('/api/clients/trigger');
      if (response.statusCode == 200) {
        return ClientTriggerModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to fetch trigger');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Create (or replace) the trigger for the current tenant.
  Future<ClientTriggerModel> createTrigger({
    required String templateName,
    String language = 'en_US',
    String mediaId = '',
    String mediaType = '',
    Map<String, String> variableMapping = const {},
  }) async {
    try {
      final response = await _dio.post('/api/clients/trigger', data: {
        'templateName': templateName,
        'templateLanguage': language,
        'mediaId': mediaId,
        'mediaType': mediaType,
        'variableMapping': variableMapping,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ClientTriggerModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to create trigger');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to create trigger');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Update allowed fields on the existing trigger.
  Future<ClientTriggerModel> updateTrigger({
    bool? isActive,
    String? templateName,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (isActive != null) data['isActive'] = isActive;
      if (templateName != null) data['templateName'] = templateName;

      final response = await _dio.put('/api/clients/trigger', data: data);
      if (response.statusCode == 200) {
        return ClientTriggerModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to update trigger');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to update trigger');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Delete the current tenant's trigger.
  Future<void> deleteTrigger() async {
    try {
      final response = await _dio.delete('/api/clients/trigger');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete trigger');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to delete trigger');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
