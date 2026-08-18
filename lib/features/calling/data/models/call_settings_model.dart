import 'package:equatable/equatable.dart';

class OperatingHoursDay extends Equatable {
  final String dayOfWeek;  // MONDAY, TUESDAY ...
  final String openTime;   // e.g. "0900"
  final String closeTime;  // e.g. "1700"

  const OperatingHoursDay({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
  });

  factory OperatingHoursDay.fromJson(Map<String, dynamic> json) {
    return OperatingHoursDay(
      dayOfWeek: json['day_of_week'] as String? ?? 'MONDAY',
      openTime: json['open_time']?.toString() ?? '0900',
      closeTime: json['close_time']?.toString() ?? '1700',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'open_time': openTime,
      'close_time': closeTime,
    };
  }

  @override
  List<Object?> get props => [dayOfWeek, openTime, closeTime];
}

class CallHoursModel extends Equatable {
  final bool enabled;
  final String timezoneId;
  final List<OperatingHoursDay> weeklyOperatingHours;

  const CallHoursModel({
    required this.enabled,
    required this.timezoneId,
    required this.weeklyOperatingHours,
  });

  factory CallHoursModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'DISABLED';
    final hoursList = (json['weekly_operating_hours'] as List<dynamic>?)
            ?.map((e) => OperatingHoursDay.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CallHoursModel(
      enabled: status.toUpperCase() == 'ENABLED',
      timezoneId: json['timezone_id'] as String? ?? 'UTC',
      weeklyOperatingHours: hoursList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': enabled ? 'ENABLED' : 'DISABLED',
      'timezone_id': timezoneId,
      'weekly_operating_hours': weeklyOperatingHours.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [enabled, timezoneId, weeklyOperatingHours];
}

class VoicemailSettingsModel extends Equatable {
  final bool enabled;
  final List<String> triggers; // REJECT, TIMEOUT
  final String? announcementMediaId;
  final int timeoutSeconds;

  const VoicemailSettingsModel({
    required this.enabled,
    required this.triggers,
    this.announcementMediaId,
    required this.timeoutSeconds,
  });

  factory VoicemailSettingsModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'DISABLED';
    final triggerList = (json['triggers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final audioObj = json['audio'] as Map<String, dynamic>? ?? {};
    final defaultObj = audioObj['default'] as Map<String, dynamic>? ?? {};

    return VoicemailSettingsModel(
      enabled: status.toUpperCase() == 'ENABLED',
      triggers: triggerList,
      announcementMediaId: defaultObj['announcement_media_id']?.toString(),
      timeoutSeconds: defaultObj['timeout_seconds'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': enabled ? 'ENABLED' : 'DISABLED',
      'triggers': triggers,
      'audio': {
        'default': {
          if (announcementMediaId != null) 'announcement_media_id': announcementMediaId,
          'timeout_seconds': timeoutSeconds,
        }
      }
    };
  }

  @override
  List<Object?> get props => [enabled, triggers, announcementMediaId, timeoutSeconds];
}

class CallSettingsModel extends Equatable {
  final bool callingEnabled;
  final String callIconVisibility;      // DEFAULT, DISABLE_ALL
  final bool callbackPermissionStatus; // ENABLED, DISABLED
  final CallHoursModel? callHours;
  final VoicemailSettingsModel? voicemail;
  final List<String> additionalCodecs; // PCMA, PCMU

  const CallSettingsModel({
    required this.callingEnabled,
    required this.callIconVisibility,
    required this.callbackPermissionStatus,
    this.callHours,
    this.voicemail,
    this.additionalCodecs = const [],
  });

  factory CallSettingsModel.fromJson(Map<String, dynamic> json) {
    final calling = json['calling'] as Map<String, dynamic>? ?? json;
    final status = calling['status'] as String? ?? 'DISABLED';
    final visibility = calling['call_icon_visibility'] as String? ?? 'DEFAULT';
    final callbackPerm = calling['callback_permission_status'] as String? ?? 'ENABLED';

    final audio = calling['audio'] as Map<String, dynamic>? ?? {};
    final codecs = (audio['additional_codecs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return CallSettingsModel(
      callingEnabled: status.toUpperCase() == 'ENABLED',
      callIconVisibility: visibility,
      callbackPermissionStatus: callbackPerm.toUpperCase() == 'ENABLED',
      callHours: calling['call_hours'] != null
          ? CallHoursModel.fromJson(calling['call_hours'] as Map<String, dynamic>)
          : null,
      voicemail: calling['voicemail'] != null
          ? VoicemailSettingsModel.fromJson(calling['voicemail'] as Map<String, dynamic>)
          : null,
      additionalCodecs: codecs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calling': {
        'status': callingEnabled ? 'ENABLED' : 'DISABLED',
        'call_icon_visibility': callIconVisibility,
        'callback_permission_status': callbackPermissionStatus ? 'ENABLED' : 'DISABLED',
        if (callHours != null) 'call_hours': callHours!.toJson(),
        if (voicemail != null) 'voicemail': voicemail!.toJson(),
        'audio': {
          'additional_codecs': additionalCodecs,
        }
      }
    };
  }

  @override
  List<Object?> get props => [
        callingEnabled,
        callIconVisibility,
        callbackPermissionStatus,
        callHours,
        voicemail,
        additionalCodecs,
      ];
}
