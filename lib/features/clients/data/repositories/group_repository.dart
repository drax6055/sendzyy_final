import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';

class GroupRepository {
  final Dio _dio;

  GroupRepository(this._dio);

  Future<List<GroupModel>> getGroups() async {
    try {
      final response = await _dio.get('/api/groups');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => GroupModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load groups');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to load groups');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<GroupModel> createGroup(String name, List<String> clientIds) async {
    try {
      final response = await _dio.post(
        '/api/groups',
        data: {'name': name, 'clientIds': clientIds},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return GroupModel.fromJson(response.data);
      } else {
        throw Exception('Failed to create group');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to create group');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<GroupModel> updateGroup(
      String id, String name, List<String> clientIds) async {
    try {
      final response = await _dio.put(
        '/api/groups/$id',
        data: {'name': name, 'clientIds': clientIds},
      );
      if (response.statusCode == 200) {
        return GroupModel.fromJson(response.data);
      } else {
        throw Exception('Failed to update group');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to update group');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      final response = await _dio.delete('/api/groups/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete group');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic> &&
          (e.response!.data as Map).containsKey('error')) {
        throw Exception(e.response!.data['error']);
      }
      throw Exception(e.message ?? 'Failed to delete group');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
