import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_permission_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_settings_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';
import 'calling_repository.dart';

class CallingRepositoryImpl implements CallingRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  CallingRepositoryImpl(this._dio, this._prefs);

  String? get _accessToken => _prefs.getString(AppConstants.keyAccessToken);
  String? get _phoneNumberId => _prefs.getString(AppConstants.keyPhoneNumberId);

  Options _getAuthOptions() {
    return Options(
      headers: {
        'Authorization': 'Bearer ${_accessToken ?? ''}',
        'Content-Type': 'application/json',
      },
    );
  }

  String _buildGraphUrl(String path) {
    // If path starts with slash, trim it
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'https://graph.facebook.com/v21.0/$cleanPath';
  }

  @override
  Future<CallSettingsModel> getCallSettings(String phoneNumberId) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/settings');
    final response = await _dio.get(url, options: _getAuthOptions());
    return CallSettingsModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> updateCallSettings({
    required String phoneNumberId,
    required CallSettingsModel settings,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/settings');
    final response = await _dio.post(
      url,
      data: settings.toJson(),
      options: _getAuthOptions(),
    );
    return response.statusCode == 200 && (response.data['success'] == true);
  }

  @override
  Future<CallPermissionModel> getCallPermission({
    required String phoneNumberId,
    String? userWaId,
    String? recipientBsuid,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final queryParams = <String, String>{};
    if (recipientBsuid != null && recipientBsuid.isNotEmpty) {
      queryParams['recipient'] = recipientBsuid;
    } else if (userWaId != null && userWaId.isNotEmpty) {
      queryParams['user_wa_id'] = userWaId;
    }

    final url = _buildGraphUrl('$targetId/call_permissions');
    final response = await _dio.get(
      url,
      queryParameters: queryParams,
      options: _getAuthOptions(),
    );
    return CallPermissionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> sendCallPermissionRequest({
    required String phoneNumberId,
    required String to,
    String? bodyText,
    String? recipientBsuid,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/messages');
    final payload = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      if (to.isNotEmpty) 'to': to,
      if (recipientBsuid != null && recipientBsuid.isNotEmpty) 'recipient': recipientBsuid,
      'type': 'interactive',
      'interactive': {
        'type': 'call_permission_request',
        'action': {'name': 'call_permission_request'},
        if (bodyText != null && bodyText.isNotEmpty)
          'body': {'text': bodyText},
      }
    };

    final response = await _dio.post(
      url,
      data: payload,
      options: _getAuthOptions(),
    );

    final messages = response.data['messages'] as List<dynamic>?;
    if (messages != null && messages.isNotEmpty) {
      return messages.first['id'] as String? ?? '';
    }
    return '';
  }

  @override
  Future<String> sendVoiceCallButtonMessage({
    required String phoneNumberId,
    required String to,
    String? displayText,
    int? ttlMinutes,
    String? payload,
    String? recipientBsuid,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/messages');
    final bodyPayload = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      if (to.isNotEmpty) 'to': to,
      if (recipientBsuid != null && recipientBsuid.isNotEmpty) 'recipient': recipientBsuid,
      'type': 'interactive',
      'interactive': {
        'type': 'voice_call',
        'body': {'text': 'You can call us on WhatsApp now!'},
        'action': {
          'name': 'voice_call',
          'parameters': {
            'display_text': displayText ?? 'Call Now',
            'ttl_minutes': ttlMinutes ?? 10080,
            if (payload != null) 'payload': payload,
          }
        }
      }
    };

    final response = await _dio.post(
      url,
      data: bodyPayload,
      options: _getAuthOptions(),
    );

    final messages = response.data['messages'] as List<dynamic>?;
    if (messages != null && messages.isNotEmpty) {
      return messages.first['id'] as String? ?? '';
    }
    return '';
  }

  @override
  Future<CallModel> initiateCall({
    required String phoneNumberId,
    required String to,
    required SdpSessionModel session,
    String? recipientBsuid,
    String? bizOpaqueCallbackData,
    bool enableRecording = false,
    bool enableTranscription = false,
    String? recordingPurpose,
    String announcementLanguage = 'en_US',
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/calls');
    final payload = <String, dynamic>{
      'messaging_product': 'whatsapp',
      if (to.isNotEmpty) 'to': to,
      if (recipientBsuid != null && recipientBsuid.isNotEmpty) 'recipient': recipientBsuid,
      'action': 'connect',
      'session': session.toJson(),
      if (bizOpaqueCallbackData != null) 'biz_opaque_callback_data': bizOpaqueCallbackData,
    };

    if (enableRecording) {
      payload['recording'] = {
        'status': 'ENABLED',
        'purpose': recordingPurpose ?? 'quality assurance',
        'announcement_language': announcementLanguage,
      };
    }
    if (enableTranscription) {
      payload['transcription'] = {
        'status': 'ENABLED',
        'purpose': recordingPurpose ?? 'quality assurance',
        'announcement_language': announcementLanguage,
      };
    }

    final response = await _dio.post(
      url,
      data: payload,
      options: _getAuthOptions(),
    );

    final calls = response.data['calls'] as List<dynamic>?;
    final callId = (calls != null && calls.isNotEmpty)
        ? calls.first['id'] as String? ?? ''
        : '';

    return CallModel(
      callId: callId,
      to: to,
      from: targetId,
      direction: CallDirection.businessInitiated,
      status: CallStatus.connecting,
      timestamp: DateTime.now(),
      session: session,
      bizOpaqueCallbackData: bizOpaqueCallbackData,
    );
  }

  @override
  Future<bool> preAcceptCall({
    required String phoneNumberId,
    required String callId,
    required SdpSessionModel session,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/calls');
    final response = await _dio.post(
      url,
      data: {
        'messaging_product': 'whatsapp',
        'call_id': callId,
        'action': 'pre_accept',
        'session': session.toJson(),
      },
      options: _getAuthOptions(),
    );
    return response.statusCode == 200 && (response.data['success'] == true);
  }

  @override
  Future<bool> acceptCall({
    required String phoneNumberId,
    required String callId,
    required SdpSessionModel session,
    String? bizOpaqueCallbackData,
    bool enableRecording = false,
    bool enableTranscription = false,
    String? recordingPurpose,
    String announcementLanguage = 'en_US',
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/calls');
    final payload = <String, dynamic>{
      'messaging_product': 'whatsapp',
      'call_id': callId,
      'action': 'accept',
      'session': session.toJson(),
      if (bizOpaqueCallbackData != null) 'biz_opaque_callback_data': bizOpaqueCallbackData,
    };

    if (enableRecording) {
      payload['recording'] = {
        'status': 'ENABLED',
        'purpose': recordingPurpose ?? 'quality assurance',
        'announcement_language': announcementLanguage,
      };
    }
    if (enableTranscription) {
      payload['transcription'] = {
        'status': 'ENABLED',
        'purpose': recordingPurpose ?? 'quality assurance',
        'announcement_language': announcementLanguage,
      };
    }

    final response = await _dio.post(
      url,
      data: payload,
      options: _getAuthOptions(),
    );
    return response.statusCode == 200 && (response.data['success'] == true);
  }

  @override
  Future<bool> rejectCall({
    required String phoneNumberId,
    required String callId,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/calls');
    final response = await _dio.post(
      url,
      data: {
        'messaging_product': 'whatsapp',
        'call_id': callId,
        'action': 'reject',
      },
      options: _getAuthOptions(),
    );
    return response.statusCode == 200 && (response.data['success'] == true);
  }

  @override
  Future<bool> terminateCall({
    required String phoneNumberId,
    required String callId,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/calls');
    final response = await _dio.post(
      url,
      data: {
        'messaging_product': 'whatsapp',
        'call_id': callId,
        'action': 'terminate',
      },
      options: _getAuthOptions(),
    );
    return response.statusCode == 200 && (response.data['success'] == true);
  }

  @override
  Future<String> uploadVoicemailAnnouncement({
    required String phoneNumberId,
    required String filePath,
    required String description,
  }) async {
    final targetId = phoneNumberId.isNotEmpty ? phoneNumberId : (_phoneNumberId ?? '');
    final url = _buildGraphUrl('$targetId/media');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'announcement.ogg'),
      'messaging_product': 'whatsapp',
      'use_case': 'call_voicemail_announcement',
      'description': description,
    });

    final response = await _dio.post(
      url,
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_accessToken ?? ''}',
        },
      ),
    );
    return response.data['id'] as String? ?? '';
  }
}
