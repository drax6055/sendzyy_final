import 'package:flutter/material.dart';

class CallButtonComposer extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onChanged;

  const CallButtonComposer({super.key, required this.onChanged});

  @override
  State<CallButtonComposer> createState() => _CallButtonComposerState();
}

class _CallButtonComposerState extends State<CallButtonComposer> {
  bool _enableCallButton = false;
  final _displayTextController = TextEditingController(text: 'Call Now');
  final _payloadController = TextEditingController();
  int _ttlMinutes = 10080; // Default 7 days

  void _notify() {
    widget.onChanged({
      'enabled': _enableCallButton,
      'display_text': _displayTextController.text.trim(),
      'ttl_minutes': _ttlMinutes,
      'payload': _payloadController.text.trim(),
    });
  }

  @override
  void dispose() {
    _displayTextController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Row(
                children: [
                  Icon(Icons.add_call, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Attach WhatsApp Call Button', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              subtitle: const Text('Add an interactive Call CTA button to your message.'),
              value: _enableCallButton,
              onChanged: (val) {
                setState(() => _enableCallButton = val);
                _notify();
              },
            ),
            if (_enableCallButton) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _displayTextController,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Button Display Text',
                  hintText: 'Call Now',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _notify(),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _ttlMinutes,
                decoration: const InputDecoration(
                  labelText: 'Button Validity (TTL)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 Hour')),
                  DropdownMenuItem(value: 1440, child: Text('1 Day')),
                  DropdownMenuItem(value: 10080, child: Text('7 Days (Default)')),
                  DropdownMenuItem(value: 43200, child: Text('30 Days')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _ttlMinutes = val);
                    _notify();
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _payloadController,
                maxLength: 512,
                decoration: const InputDecoration(
                  labelText: 'Tracking Payload (Optional)',
                  hintText: 'e.g. campaign_lead_123',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _notify(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
