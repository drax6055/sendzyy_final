import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/features/app_update/domain/models/app_update_info.dart';

class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final AppUpdateInfo? updateInfo;
  final String? message;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.updateInfo,
    this.message,
  });
}

class AppUpdateService {
  final Dio _dio;
  CancelToken? _downloadCancelToken;

  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// Retrieves the installed app version and build number
  Future<PackageInfo> getInstalledPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// Checks server for available Android update
  Future<UpdateCheckResult> checkForUpdate({String? customBaseUrl}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: '1.0.0',
        currentBuildNumber: 1,
        message: 'Self-update is only supported on Android devices.',
      );
    }

    try {
      final packageInfo = await getInstalledPackageInfo();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final baseUrl = customBaseUrl ?? AppConstants.baseUrl;
      if (baseUrl.isEmpty) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          message: 'Server BASE_URL is not configured.',
        );
      }

      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await _dio.get(
        '$cleanBase/api/app/version',
        queryParameters: {'platform': 'android'},
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final updateInfo = AppUpdateInfo.fromJson(data['data']);

          // Compare build numbers (server buildNumber > current installed buildNumber)
          final hasUpdate = updateInfo.buildNumber > currentBuildNumber;

          return UpdateCheckResult(
            hasUpdate: hasUpdate,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
            updateInfo: updateInfo,
          );
        }
      }

      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        message: 'No active update found on server.',
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for update: $e');
      final packageInfo = await getInstalledPackageInfo().catchError((_) => PackageInfo(
            appName: 'Sendzyy',
            packageName: 'com.iflorainfopvtltd.sendzyy',
            version: '1.0.0',
            buildNumber: '1',
            buildSignature: '',
          ));

      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
        message: 'Update check failed: $e',
      );
    }
  }

  /// Downloads the APK from server with live progress reporting
  Future<File> downloadApk({
    required AppUpdateInfo updateInfo,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    _downloadCancelToken = CancelToken();

    final apkUrl = updateInfo.apkUrl;
    final uri = Uri.tryParse(apkUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw Exception('Invalid APK download URL: $apkUrl');
    }

    // Determine storage directory for APK
    Directory storageDir;
    try {
      final extDirs = await getExternalCacheDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        storageDir = extDirs.first;
      } else {
        storageDir = await getTemporaryDirectory();
      }
    } catch (_) {
      storageDir = await getTemporaryDirectory();
    }

    final sanitizedFileName = 'sendzyy-update-${updateInfo.version}-${updateInfo.buildNumber}.apk';
    final targetFile = File('${storageDir.path}/$sanitizedFileName');

    // Clean up if a previous partial file exists
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    try {
      await _dio.download(
        apkUrl,
        targetFile.path,
        cancelToken: _downloadCancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            onProgress(progress, received, total);
          } else {
            onProgress(0.0, received, total);
          }
        },
      );

      // Verify file integrity via SHA-256
      if (updateInfo.sha256.isNotEmpty) {
        final isValid = await _verifySha256(targetFile, updateInfo.sha256);
        if (!isValid) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          throw Exception('APK file integrity check failed (SHA-256 mismatch). Please try again.');
        }
      }

      return targetFile;
    } catch (e) {
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _downloadCancelToken = null;
    }
  }


  /// Cancels any active download
  void cancelDownload() {
    if (_downloadCancelToken != null && !_downloadCancelToken!.isCancelled) {
      _downloadCancelToken!.cancel('Download cancelled by user');
    }
  }

  /// Checks if "Install unknown apps" permission is granted
  Future<bool> checkInstallPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  /// Requests "Install unknown apps" permission
  Future<bool> requestInstallPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// Opens app settings if permission cannot be granted directly
  Future<bool> openInstallPermissionSettings() async {
    return await openAppSettings();
  }

  /// Triggers the Android PackageInstaller to install the downloaded APK
  Future<OpenResult> installApk(File apkFile) async {
    if (!await apkFile.exists()) {
      throw Exception('APK file not found at ${apkFile.path}');
    }

    final result = await OpenFile.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      debugPrint('[AppUpdateService] OpenFile result: ${result.type} - ${result.message}');
    }

    return result;
  }

  /// Computes SHA-256 of the downloaded file and compares against expected checksum
  Future<bool> _verifySha256(File file, String expectedHash) async {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      final computedHash = digest.toString().toLowerCase().trim();
      final expected = expectedHash.toLowerCase().trim();
      return computedHash == expected;
    } catch (e) {
      debugPrint('[AppUpdateService] SHA-256 verification error: $e');
      return false;
    }
  }
}
