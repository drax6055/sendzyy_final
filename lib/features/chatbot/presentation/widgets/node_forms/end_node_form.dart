import 'package:flutter/material.dart';

class EndNodeForm extends StatelessWidget {
  const EndNodeForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.stop_circle_outlined, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'This node ends the conversation.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
