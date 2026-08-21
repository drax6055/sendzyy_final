import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/chatbot_model.dart';

class ChatbotRepository {
  final Dio _dio;

  ChatbotRepository(this._dio);

  Future<List<ChatbotModel>> fetchAll() async {
    try {
      final response = await _dio.get('/api/chatbots');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatbotModel.fromJson(json)).toList();
      }
      throw Exception('Failed to load chatbots');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load chatbots');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ChatbotModel> fetchOne(String id) async {
    try {
      final response = await _dio.get('/api/chatbots/$id');
      if (response.statusCode == 200) {
        return ChatbotModel.fromJson(response.data);
      }
      throw Exception('Failed to load chatbot');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load chatbot');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ChatbotModel> create(
    String name,
    List<String> keywords,
    Map<String, dynamic> flow,
  ) async {
    try {
      final response = await _dio.post(
        '/api/chatbots',
        data: {'name': name, 'triggerKeywords': keywords, 'flow': flow},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatbotModel.fromJson(response.data);
      }
      throw Exception('Failed to create chatbot');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to create chatbot');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ChatbotModel> update(String id, Map<String, dynamic> fields) async {
    try {
      final response = await _dio.put('/api/chatbots/$id', data: fields);
      if (response.statusCode == 200) {
        return ChatbotModel.fromJson(response.data);
      }
      throw Exception('Failed to update chatbot');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception(_extractError(e) ?? 'Duplicate trigger keyword conflict');
      }
      throw Exception(_extractError(e) ?? 'Failed to update chatbot');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> delete(String id) async {
    try {
      final response = await _dio.delete('/api/chatbots/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete chatbot');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to delete chatbot');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ChatbotModel> toggleActive(String id, bool isActive) async {
    return update(id, {'isActive': isActive});
  }

  Future<List<DailyAnalytics>> fetchAnalytics(String chatbotId, {int days = 7}) async {
    try {
      final response = await _dio.get('/api/chatbots/$chatbotId/analytics?days=$days');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => DailyAnalytics.fromJson(json)).toList();
      }
      throw Exception('Failed to load analytics');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to load analytics');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> resetSession(String contactId) async {
    try {
      final response = await _dio.delete('/api/chatbots/sessions/$contactId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to reset session');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to reset session');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  String? _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['error'] as String? ?? data['message'] as String?;
    }
    return e.message;
  }
}
