import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_permission_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/widgets/call_permission_card.dart';

class CallPermissionPage extends StatefulWidget {
  final String phoneNumberId;
  final String userWaId;

  const CallPermissionPage({
    super.key,
    required this.phoneNumberId,
    required this.userWaId,
  });

  @override
  State<CallPermissionPage> createState() => _CallPermissionPageState();
}

class _CallPermissionPageState extends State<CallPermissionPage> {
  final _bodyTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CallPermissionBloc>().add(CheckCallPermissionEvent(
          phoneNumberId: widget.phoneNumberId,
          userWaId: widget.userWaId,
        ));
  }

  @override
  void dispose() {
    _bodyTextController.dispose();
    super.dispose();
  }

  void _showRequestDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Call Permission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send a WhatsApp message requesting permission to call this user. Rate limits apply (max 1/24h, 2/7d).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyTextController,
              decoration: const InputDecoration(
                labelText: 'Message Body (Optional)',
                hintText: 'We would like to call you regarding your support ticket.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CallPermissionBloc>().add(
                    SendCallPermissionRequestEvent(
                      phoneNumberId: widget.phoneNumberId,
                      to: widget.userWaId,
                      bodyText: _bodyTextController.text.trim(),
                    ),
                  );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Call Permissions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient: ${widget.userWaId}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            BlocConsumer<CallPermissionBloc, CallPermissionState>(
              listener: (context, state) {
                if (state is CallPermissionLoaded && state.statusMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.statusMessage!)),
                  );
                }
              },
              builder: (context, state) {
                if (state is CallPermissionLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is CallPermissionError) {
                  return Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        state.message,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  );
                }
                if (state is CallPermissionLoaded) {
                  return CallPermissionCard(
                    permission: state.permission,
                    onRequestPermission: _showRequestDialog,
                    onStartCall: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Starting business-initiated call...')),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }
}
