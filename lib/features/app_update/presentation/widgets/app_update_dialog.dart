import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/app_update/domain/models/app_update_info.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_bloc.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_event.dart';
import 'package:iFloraBuzz/features/app_update/presentation/bloc/app_update_state.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    required this.currentBuildNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: BlocProvider.of<AppUpdateBloc>(context),
          child: AppUpdateDialog(
            updateInfo: updateInfo,
            currentVersion: currentVersion,
            currentBuildNumber: currentBuildNumber,
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final isForce = updateInfo.forceUpdate;

    return PopScope(
      canPop: !isForce,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 12,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: BlocConsumer<AppUpdateBloc, AppUpdateState>(
          listener: (context, state) {
            // If download & install completes, or dialog dismissed, close if optional
            if (state is AppUpdateInitial && !isForce) {
              Navigator.of(context, rootNavigator: true).maybePop();
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isForce),
                  const SizedBox(height: 18),
                  _buildVersionBadge(context),
                  const SizedBox(height: 16),
                  if (state is! AppUpdateDownloading &&
                      state is! AppUpdatePermissionRequired &&
                      state is! AppUpdateError &&
                      updateInfo.releaseNotes.isNotEmpty) ...[
                    _buildReleaseNotes(context),
                    const SizedBox(height: 20),
                  ],
                  _buildDynamicContent(context, state, isForce),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isForce) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isForce
                ? Colors.red.withValues(alpha: 0.12)
                : AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isForce ? Icons.system_security_update_warning_rounded : Icons.system_update_rounded,
            color: isForce ? Colors.red.shade700 : AppTheme.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isForce ? 'Mandatory Update' : 'New Update Available',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isForce
                    ? 'Please update to continue using Sendzyy'
                    : 'A new version of Sendzyy is ready',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Version',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                'v$currentVersion ($currentBuildNumber)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Latest Version',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                'v${updateInfo.version} (${updateInfo.buildNumber})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNotes(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "What's New:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            if (updateInfo.fileSize > 0)
              Text(
                'Size: ${_formatBytes(updateInfo.fileSize)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: updateInfo.releaseNotes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: 8),
                    child: Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
                  ),
                  Expanded(
                    child: Text(
                      updateInfo.releaseNotes[index],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicContent(BuildContext context, AppUpdateState state, bool isForce) {
    if (state is AppUpdateDownloading) {
      return _buildDownloadingView(context, state);
    } else if (state is AppUpdatePermissionRequired) {
      return _buildPermissionRequiredView(context, state.apkFile);
    } else if (state is AppUpdateInstalling) {
      return _buildInstallingView(context);
    } else if (state is AppUpdateError) {
      return _buildErrorView(context, state, isForce);
    } else {
      return _buildInitialButtons(context, isForce);
    }
  }

  Widget _buildInitialButtons(BuildContext context, bool isForce) {
    return Row(
      children: [
        if (!isForce) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                context.read<AppUpdateBloc>().add(DismissUpdateDialogEvent());
                Navigator.of(context, rootNavigator: true).maybePop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text(
                'Later',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: isForce ? 1 : 1,
          child: ElevatedButton(
            onPressed: () {
              context.read<AppUpdateBloc>().add(StartUpdateDownloadEvent(updateInfo));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 18),
                SizedBox(width: 6),
                Text(
                  'Update Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingView(BuildContext context, AppUpdateDownloading state) {
    final percent = (state.progress * 100).toInt();
    final downloadedText = state.totalBytes > 0
        ? '${_formatBytes(state.receivedBytes)} / ${_formatBytes(state.totalBytes)}'
        : _formatBytes(state.receivedBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Downloading update...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: state.progress > 0 ? state.progress : null,
            minHeight: 10,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              downloadedText,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (!updateInfo.forceUpdate)
              InkWell(
                onTap: () {
                  context.read<AppUpdateBloc>().add(CancelUpdateDownloadEvent());
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionRequiredView(BuildContext context, File apkFile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'To install the update, please grant Sendzyy permission to "Install unknown apps" in system settings.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.3),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<AppUpdateBloc>().add(RequestInstallPermissionEvent(
                      updateInfo: updateInfo,
                      apkFile: apkFile,
                    ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Grant Permission & Install',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallingView(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryColor),
            ),
            SizedBox(width: 12),
            Text(
              'Launching installer...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, AppUpdateError state, bool isForce) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.message,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (!isForce) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).maybePop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  context.read<AppUpdateBloc>().add(StartUpdateDownloadEvent(updateInfo));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
