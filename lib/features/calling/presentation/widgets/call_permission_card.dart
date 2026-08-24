import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_permission_model.dart';
import 'package:intl/intl.dart';

class CallPermissionCard extends StatelessWidget {
  final CallPermissionModel permission;
  final VoidCallback onRequestPermission;
  final VoidCallback onStartCall;

  const CallPermissionCard({
    super.key,
    required this.permission,
    required this.onRequestPermission,
    required this.onStartCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (permission.status) {
      case PermissionStatusState.permanent:
        statusColor = Colors.green;
        statusTitle = 'Permanent Call Permission Granted';
        statusIcon = Icons.verified_user;
        break;
      case PermissionStatusState.temporary:
        statusColor = Colors.amber.shade700;
        statusTitle = 'Temporary Call Permission (7 Days)';
        statusIcon = Icons.timer;
        break;
      case PermissionStatusState.noPermission:
      default:
        statusColor = Colors.red.shade700;
        statusTitle = 'No Call Permission Granted';
        statusIcon = Icons.gpp_bad;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (permission.expirationTime != null) ...[
              const SizedBox(height: 6),
              Text(
                'Expires: ${DateFormat('yyyy-MM-dd HH:mm').format(permission.expirationTime!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (permission.canStartCall)
                  ElevatedButton.icon(
                    onPressed: onStartCall,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (permission.canStartCall) const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onRequestPermission,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Request Permission'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
