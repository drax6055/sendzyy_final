import 'package:dio/dio.dart';

/// Repository for all retry-phase related API calls.
class RetryRepository {
  final Dio _dio;

  RetryRepository(this._dio);

  // ── Configuration ──────────────────────────────────────────────────────────

  /// GET /api/retry-config/current
  Future<Map<String, dynamic>?> getActiveConfig() async {
    try {
      final res = await _dio.get('/api/retry-config/current');
      if (res.statusCode == 200) return Map<String, dynamic>.from(res.data);
    } catch (_) {}
    return null;
  }

  /// GET /api/retry-config/history
  Future<List<Map<String, dynamic>>> getConfigHistory() async {
    try {
      final res = await _dio.get('/api/retry-config/history');
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['configs'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// POST /api/retry-config
  /// [phases] is a list of {phaseNumber, intervalHours}
  Future<Map<String, dynamic>> saveConfig(
      List<Map<String, dynamic>> phases) async {
    final res = await _dio.post('/api/retry-config', data: {'phases': phases});
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Map<String, dynamic>.from(res.data);
    }
    final err = res.data?['error'] ?? 'Failed to save configuration';
    throw Exception(err);
  }

  // ── Campaign Phase Report ──────────────────────────────────────────────────

  /// GET /api/campaigns/:campaignId/report
  Future<Map<String, dynamic>?> getCampaignReport(String campaignId) async {
    try {
      final res = await _dio.get('/api/campaigns/$campaignId/report');
      if (res.statusCode == 200) return Map<String, dynamic>.from(res.data);
    } catch (_) {}
    return null;
  }

  // ── Admin Health ───────────────────────────────────────────────────────────

  /// GET /api/admin/retry-system/health
  Future<Map<String, dynamic>?> getSystemHealth() async {
    try {
      final res = await _dio.get('/api/admin/retry-system/health');
      if (res.statusCode == 200) return Map<String, dynamic>.from(res.data);
    } catch (_) {}
    return null;
  }

  /// GET /api/admin/retry-system/logs
  Future<Map<String, dynamic>> getLogs({
    int page = 1,
    String? campaignId,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (campaignId != null && campaignId.isNotEmpty) {
      params['campaignId'] = campaignId;
    }
    final res = await _dio.get('/api/admin/retry-system/logs',
        queryParameters: params);
    if (res.statusCode == 200) return Map<String, dynamic>.from(res.data);
    throw Exception('Failed to fetch logs');
  }
}
