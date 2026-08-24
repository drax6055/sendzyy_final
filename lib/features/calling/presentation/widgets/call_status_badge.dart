import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_model.dart';

class CallStatusBadge extends StatelessWidget {
  final CallStatus status;

  const CallStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case CallStatus.accepted:
      case CallStatus.completed:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = status == CallStatus.accepted ? 'CONNECTED' : 'COMPLETED';
        break;
      case CallStatus.ringing:
      case CallStatus.connecting:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = status == CallStatus.ringing ? 'RINGING' : 'CONNECTING';
        break;
      case CallStatus.rejected:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'REJECTED';
        break;
      case CallStatus.failed:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'FAILED';
        break;
      case CallStatus.terminated:
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = 'ENDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
