import 'package:equatable/equatable.dart';

class AppUpdateInfo extends Equatable {
  final String platform;
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String apkFileName;
  final String sha256;
  final bool forceUpdate;
  final List<String> releaseNotes;
  final int fileSize;

  const AppUpdateInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.apkFileName,
    required this.sha256,
    required this.forceUpdate,
    required this.releaseNotes,
    this.fileSize = 0,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> parsedNotes = [];
    if (json['releaseNotes'] != null) {
      if (json['releaseNotes'] is List) {
        parsedNotes = (json['releaseNotes'] as List)
            .map((item) => item.toString())
            .toList();
      } else if (json['releaseNotes'] is String) {
        parsedNotes = [json['releaseNotes'].toString()];
      }
    }

    return AppUpdateInfo(
      platform: json['platform'] as String? ?? 'android',
      version: json['version'] as String? ?? '',
      buildNumber: (json['buildNumber'] is num)
          ? (json['buildNumber'] as num).toInt()
          : int.tryParse(json['buildNumber']?.toString() ?? '0') ?? 0,
      apkUrl: json['apkUrl'] as String? ?? '',
      apkFileName: json['apkFileName'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      forceUpdate: json['forceUpdate'] == true || json['forceUpdate'] == 'true',
      releaseNotes: parsedNotes,
      fileSize: (json['fileSize'] is num)
          ? (json['fileSize'] as num).toInt()
          : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'version': version,
      'buildNumber': buildNumber,
      'apkUrl': apkUrl,
      'apkFileName': apkFileName,
      'sha256': sha256,
      'forceUpdate': forceUpdate,
      'releaseNotes': releaseNotes,
      'fileSize': fileSize,
    };
  }

  @override
  List<Object?> get props => [
        platform,
        version,
        buildNumber,
        apkUrl,
        apkFileName,
        sha256,
        forceUpdate,
        releaseNotes,
        fileSize,
      ];
}
