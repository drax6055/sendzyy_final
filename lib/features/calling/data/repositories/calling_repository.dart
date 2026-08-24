import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_permission_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_settings_model.dart';
import 'package:iFloraBuzz/features/calling/data/models/sdp_session_model.dart';

abstract class CallingRepository {
  /// Fetch Calling API settings for a business phone number.
  Future<CallSettingsModel> getCallSettings(String phoneNumberId);

  /// Update Calling API settings for a business phone number.
  Future<bool> updateCallSettings({
    required String phoneNumberId,
    required CallSettingsModel settings,
  });

  /// Check call permission status and rate limits for a recipient.
  Future<CallPermissionModel> getCallPermission({
    required String phoneNumberId,
    String? userWaId,
    String? recipientBsuid,
  });

  /// Send a free-form call permission request message.
  Future<String> sendCallPermissionRequest({
    required String phoneNumberId,
    required String to,
    String? bodyText,
    String? recipientBsuid,
  });

  /// Send an interactive voice_call button message.
  Future<String> sendVoiceCallButtonMessage({
    required String phoneNumberId,
    required String to,
    String? displayText,
    int? ttlMinutes,
    String? payload,
    String? recipientBsuid,
  });

  /// Initiate a new business-initiated call (BIC).
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
  });

  /// Pre-accept an incoming user-initiated call (UIC).
  Future<bool> preAcceptCall({
    required String phoneNumberId,
    required String callId,
    required SdpSessionModel session,
  });

  /// Accept an incoming user-initiated call (UIC).
  Future<bool> acceptCall({
    required String phoneNumberId,
    required String callId,
    required SdpSessionModel session,
    String? bizOpaqueCallbackData,
    bool enableRecording = false,
    bool enableTranscription = false,
    String? recordingPurpose,
    String announcementLanguage = 'en_US',
  });

  /// Reject an incoming user-initiated call (UIC).
  Future<bool> rejectCall({
    required String phoneNumberId,
    required String callId,
  });

  /// Terminate an active call (BIC or UIC).
  Future<bool> terminateCall({
    required String phoneNumberId,
    required String callId,
  });

  /// Upload media file (e.g. voicemail announcement audio).
  Future<String> uploadVoicemailAnnouncement({
    required String phoneNumberId,
    required String filePath,
    required String description,
  });
}
