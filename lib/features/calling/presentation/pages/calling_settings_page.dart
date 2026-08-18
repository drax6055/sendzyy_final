import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/data/models/call_settings_model.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_settings_bloc.dart';

class CallingSettingsPage extends StatefulWidget {
  final String phoneNumberId;

  const CallingSettingsPage({super.key, required this.phoneNumberId});

  @override
  State<CallingSettingsPage> createState() => _CallingSettingsPageState();
}

class _CallingSettingsPageState extends State<CallingSettingsPage> {
  bool _callingEnabled = false;
  String _callIconVisibility = 'DEFAULT';
  bool _callbackPermission = true;

  @override
  void initState() {
    super.initState();
    context.read<CallSettingsBloc>().add(LoadCallSettingsEvent(widget.phoneNumberId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Call Settings'),
      ),
      body: BlocConsumer<CallSettingsBloc, CallSettingsState>(
        listener: (context, state) {
          if (state is CallSettingsLoaded) {
            setState(() {
              _callingEnabled = state.settings.callingEnabled;
              _callIconVisibility = state.settings.callIconVisibility;
              _callbackPermission = state.settings.callbackPermissionStatus;
            });
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.successMessage!)),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is CallSettingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CallSettingsError) {
            return Center(child: Text(state.message));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Enable WhatsApp Calling'),
                  subtitle: const Text('Turn calling features on or off for this business number.'),
                  value: _callingEnabled,
                  onChanged: (val) {
                    setState(() => _callingEnabled = val);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Call Icon Visibility'),
                  subtitle: const Text('Control whether WhatsApp shows the call button icon in user chats.'),
                  trailing: DropdownButton<String>(
                    value: _callIconVisibility,
                    items: const [
                      DropdownMenuItem(value: 'DEFAULT', child: Text('Show (DEFAULT)')),
                      DropdownMenuItem(value: 'DISABLE_ALL', child: Text('Hide (DISABLE_ALL)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _callIconVisibility = val);
                    },
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Automatic Callback Permission'),
                  subtitle: const Text('Automatically grant temporary permission when a user calls your business.'),
                  value: _callbackPermission,
                  onChanged: (val) {
                    setState(() => _callbackPermission = val);
                  },
                ),
                const Divider(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final settings = CallSettingsModel(
                      callingEnabled: _callingEnabled,
                      callIconVisibility: _callIconVisibility,
                      callbackPermissionStatus: _callbackPermission,
                    );
                    context.read<CallSettingsBloc>().add(
                          UpdateCallSettingsEvent(
                            phoneNumberId: widget.phoneNumberId,
                            settings: settings,
                          ),
                        );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Call Settings'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
