import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:iFloraBuzz/features/app_update/data/services/app_update_service.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_event.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_state.dart';

class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  final AppUpdateService _updateService;

  AppUpdateBloc({AppUpdateService? updateService})
      : _updateService = updateService ?? AppUpdateService(),
        super(AppUpdateInitial()) {
    on<CheckForUpdateEvent>(_onCheckForUpdate);
    on<StartUpdateDownloadEvent>(_onStartUpdateDownload);
    on<CancelUpdateDownloadEvent>(_onCancelUpdateDownload);
    on<InstallDownloadedApkEvent>(_onInstallDownloadedApk);
    on<RequestInstallPermissionEvent>(_onRequestInstallPermission);
    on<DismissUpdateDialogEvent>(_onDismissUpdateDialog);
  }

  Future<void> _onCheckForUpdate(
    CheckForUpdateEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(AppUpdateChecking());
    try {
      final result = await _updateService.checkForUpdate();
      if (result.hasUpdate && result.updateInfo != null) {
        emit(AppUpdateAvailable(
          updateInfo: result.updateInfo!,
          currentVersion: result.currentVersion,
          currentBuildNumber: result.currentBuildNumber,
        ));
      } else {
        emit(AppUpdateNotAvailable(
          currentVersion: result.currentVersion,
          currentBuildNumber: result.currentBuildNumber,
          manualCheck: event.manualCheck,
        ));
      }
    } catch (e) {
      emit(AppUpdateError(
        'Failed to check for updates: $e',
      ));
    }
  }

  Future<void> _onStartUpdateDownload(
    StartUpdateDownloadEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(AppUpdateDownloading(
      updateInfo: event.updateInfo,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: event.updateInfo.fileSize,
    ));

    try {
      final apkFile = await _updateService.downloadApk(
        updateInfo: event.updateInfo,
        onProgress: (progress, received, total) {
          emit(AppUpdateDownloading(
            updateInfo: event.updateInfo,
            progress: progress,
            receivedBytes: received,
            totalBytes: total,
          ));
        },
      );

      emit(AppUpdateDownloaded(
        updateInfo: event.updateInfo,
        apkFile: apkFile,
      ));

      // Automatically trigger permission check and installation attempt
      add(InstallDownloadedApkEvent(
        updateInfo: event.updateInfo,
        apkFile: apkFile,
      ));
    } catch (e) {
      emit(AppUpdateError(
        'Download failed: $e',
        updateInfo: event.updateInfo,
      ));
    }
  }

  void _onCancelUpdateDownload(
    CancelUpdateDownloadEvent event,
    Emitter<AppUpdateState> emit,
  ) {
    _updateService.cancelDownload();
    emit(AppUpdateInitial());
  }

  Future<void> _onInstallDownloadedApk(
    InstallDownloadedApkEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    // 1. Verify "Install unknown apps" permission on Android 8+
    final hasPermission = await _updateService.checkInstallPermission();
    if (!hasPermission) {
      emit(AppUpdatePermissionRequired(
        updateInfo: event.updateInfo,
        apkFile: event.apkFile,
      ));
      return;
    }

    emit(AppUpdateInstalling(event.updateInfo));

    try {
      final result = await _updateService.installApk(event.apkFile);
      if (result.type != ResultType.done) {
        emit(AppUpdateError(
          'Installation could not be launched (${result.message}). Please ensure the APK matches the app signing certificate.',
          updateInfo: event.updateInfo,
        ));
      }
    } catch (e) {
      emit(AppUpdateError(
        'Failed to start installation: $e. If this is an existing installation, verify that the new release APK is signed with the same key.',
        updateInfo: event.updateInfo,
      ));
    }
  }

  Future<void> _onRequestInstallPermission(
    RequestInstallPermissionEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    try {
      final granted = await _updateService.requestInstallPermission();
      if (granted) {
        add(InstallDownloadedApkEvent(
          updateInfo: event.updateInfo,
          apkFile: event.apkFile,
        ));
      } else {
        // Direct request did not grant permission — open system settings screen
        await _updateService.openInstallPermissionSettings();
        emit(AppUpdatePermissionRequired(
          updateInfo: event.updateInfo,
          apkFile: event.apkFile,
        ));
      }
    } catch (e) {
      emit(AppUpdateError(
        'Permission request failed: $e',
        updateInfo: event.updateInfo,
        isPermissionError: true,
      ));
    }
  }

  void _onDismissUpdateDialog(
    DismissUpdateDialogEvent event,
    Emitter<AppUpdateState> emit,
  ) {
    emit(AppUpdateInitial());
  }
}
