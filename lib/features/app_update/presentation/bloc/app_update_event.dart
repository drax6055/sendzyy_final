import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:iFloraBuzz/features/app_update/domain/models/app_update_info.dart';

abstract class AppUpdateEvent extends Equatable {
  const AppUpdateEvent();

  @override
  List<Object?> get props => [];
}

class CheckForUpdateEvent extends AppUpdateEvent {
  final bool manualCheck;

  const CheckForUpdateEvent({this.manualCheck = false});

  @override
  List<Object?> get props => [manualCheck];
}

class StartUpdateDownloadEvent extends AppUpdateEvent {
  final AppUpdateInfo updateInfo;

  const StartUpdateDownloadEvent(this.updateInfo);

  @override
  List<Object?> get props => [updateInfo];
}

class CancelUpdateDownloadEvent extends AppUpdateEvent {}

class InstallDownloadedApkEvent extends AppUpdateEvent {
  final AppUpdateInfo updateInfo;
  final File apkFile;

  const InstallDownloadedApkEvent({
    required this.updateInfo,
    required this.apkFile,
  });

  @override
  List<Object?> get props => [updateInfo, apkFile];
}

class RequestInstallPermissionEvent extends AppUpdateEvent {
  final AppUpdateInfo updateInfo;
  final File apkFile;

  const RequestInstallPermissionEvent({
    required this.updateInfo,
    required this.apkFile,
  });

  @override
  List<Object?> get props => [updateInfo, apkFile];
}

class DismissUpdateDialogEvent extends AppUpdateEvent {}
