import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';
import 'package:iFloraBuzz/features/calling/presentation/widgets/call_status_badge.dart';
import 'package:intl/intl.dart';

class CallLogTile extends StatelessWidget {
  final CallModel call;
  final VoidCallback? onCallBack;

  const CallLogTile({
    super.key,
    required this.call,
    this.onCallBack,
  });

  @override
  Widget build(BuildContext context) {
    final isOutbound = call.direction == CallDirection.businessInitiated;
    final iconData = isOutbound ? Icons.call_made : Icons.call_received;
    final iconColor = isOutbound ? Colors.blue.shade700 : Colors.green.shade700;

    final formattedTime = DateFormat('MMM dd, yyyy • HH:mm').format(call.timestamp);
    final durationText = call.durationSeconds != null
        ? '${call.durationSeconds! ~/ 60}m ${call.durationSeconds! % 60}s'
        : '0s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          call.callerName ?? (isOutbound ? call.to : call.from),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$formattedTime • Duration: $durationText',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CallStatusBadge(status: call.status),
            if (onCallBack != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: onCallBack,
                tooltip: 'Call Back',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
