import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:iFloraBuzz/features/app_update/domain/models/app_update_info.dart';

abstract class AppUpdateState extends Equatable {
  const AppUpdateState();

  @override
  List<Object?> get props => [];
}

class AppUpdateInitial extends AppUpdateState {}

class AppUpdateChecking extends AppUpdateState {}

class AppUpdateAvailable extends AppUpdateState {
  final AppUpdateInfo updateInfo;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateAvailable({
    required this.updateInfo,
    required this.currentVersion,
    required this.currentBuildNumber,
  });

  @override
  List<Object?> get props => [updateInfo, currentVersion, currentBuildNumber];
}

class AppUpdateNotAvailable extends AppUpdateState {
  final String currentVersion;
  final int currentBuildNumber;
  final bool manualCheck;

  const AppUpdateNotAvailable({
    required this.currentVersion,
    required this.currentBuildNumber,
    this.manualCheck = false,
  });

  @override
  List<Object?> get props => [currentVersion, currentBuildNumber, manualCheck];
}

class AppUpdateDownloading extends AppUpdateState {
  final AppUpdateInfo updateInfo;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;

  const AppUpdateDownloading({
    required this.updateInfo,
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });

  @override
  List<Object?> get props => [updateInfo, progress, receivedBytes, totalBytes];
}

class AppUpdateDownloaded extends AppUpdateState {
  final AppUpdateInfo updateInfo;
  final File apkFile;

  const AppUpdateDownloaded({
    required this.updateInfo,
    required this.apkFile,
  });

  @override
  List<Object?> get props => [updateInfo, apkFile];
}

class AppUpdatePermissionRequired extends AppUpdateState {
  final AppUpdateInfo updateInfo;
  final File apkFile;

  const AppUpdatePermissionRequired({
    required this.updateInfo,
    required this.apkFile,
  });

  @override
  List<Object?> get props => [updateInfo, apkFile];
}

class AppUpdateInstalling extends AppUpdateState {
  final AppUpdateInfo updateInfo;

  const AppUpdateInstalling(this.updateInfo);

  @override
  List<Object?> get props => [updateInfo];
}

class AppUpdateError extends AppUpdateState {
  final String message;
  final AppUpdateInfo? updateInfo;
  final bool isPermissionError;

  const AppUpdateError(
    this.message, {
    this.updateInfo,
    this.isPermissionError = false,
  });

  @override
  List<Object?> get props => [message, updateInfo, isPermissionError];
}
