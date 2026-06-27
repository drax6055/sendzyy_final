import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';

class ClientRepository {
  final Dio _dio;

  ClientRepository(this._dio);

  Future<List<ClientModel>> getClients({String search = ''}) async {
    try {
      final response = await _dio.get('/api/clients', queryParameters: {
        'limit': 10000,
        if (search.isNotEmpty) 'search': search,
      });
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        return (data['clients'] as List)
            .map((json) => ClientModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load clients');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      final response = await _dio.delete('/api/clients/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete client');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
          throw Exception(errorData['error']);
        }
      }
      throw Exception(e.message ?? 'Failed to delete client');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ClientModel> createClient(ClientModel client) async {    try {
      final response = await _dio.post(
        '/api/clients',
        data: client.toJson(),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ClientModel.fromJson(response.data);
      } else {
        throw Exception('Failed to create client');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
          throw Exception(errorData['error']);
        }
      }
      throw Exception(e.message ?? 'Failed to create client');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<List<ClientModel>> bulkImportClients(List<ClientModel> clients) async {
    try {
      final response = await _dio.post(
        '/api/clients/bulk',
        data: clients.map((c) => c.toJson()).toList(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data;
        return data.map((json) => ClientModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to import clients');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to import clients');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<List<ClientModel>> bulkResolveClients(List<ClientModel> clients) async {
    try {
      final response = await _dio.post(
        '/api/clients/bulk-resolve',
        data: clients.map((c) => c.toJson()).toList(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data;
        return data.map((json) => ClientModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to resolve clients');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to resolve clients');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
