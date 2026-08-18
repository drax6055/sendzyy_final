import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_control_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/widgets/in_call_dialpad.dart';

class ActiveCallPage extends StatefulWidget {
  const ActiveCallPage({super.key});

  @override
  State<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends State<ActiveCallPage> {
  bool _showDialpad = false;

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: BlocConsumer<CallControlBloc, CallControlState>(
          listener: (context, state) {
            if (state is CallTerminatedState || state is CallIdle) {
              Navigator.of(context).maybePop();
            }
          },
          builder: (context, state) {
            if (state is CallIdle) {
              return const Center(child: Text('No Active Call', style: TextStyle(color: Colors.white)));
            }

            String titleName = 'WhatsApp Call';
            String subtitleStatus = 'Connecting...';
            bool isConnected = false;
            bool isMuted = false;
            bool isSpeaker = false;
            int durationSecs = 0;

            if (state is CallConnectingState) {
              titleName = state.callerName ?? state.to;
              subtitleStatus = 'Calling...';
            } else if (state is CallRingingState) {
              titleName = state.callerName ?? state.to;
              subtitleStatus = 'Ringing...';
            } else if (state is CallIncomingState) {
              titleName = state.callerName ?? state.from;
              subtitleStatus = 'Incoming WhatsApp Call';
            } else if (state is CallConnectedState) {
              titleName = state.call.callerName ?? state.call.to;
              isConnected = true;
              isMuted = state.isMuted;
              isSpeaker = state.isSpeaker;
              durationSecs = state.durationSeconds;
              subtitleStatus = _formatDuration(durationSecs);
            }

            return Stack(
              children: [
                Column(
                  children: [
                    const Spacer(),
                    // Caller avatar
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: theme.primaryColor,
                      child: const Icon(Icons.person, size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      titleName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleStatus,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),

                    // In-call actions / buttons
                    if (state is CallIncomingState)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 48.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Decline
                            FloatingActionButton(
                              heroTag: 'decline_btn',
                              backgroundColor: Colors.red,
                              onPressed: () {
                                context.read<CallControlBloc>().add(const RejectCallEvent());
                              },
                              child: const Icon(Icons.call_end, color: Colors.white),
                            ),
                            // Accept
                            FloatingActionButton(
                              heroTag: 'accept_btn',
                              backgroundColor: Colors.green,
                              onPressed: () {
                                context.read<CallControlBloc>().add(const AcceptCallEvent());
                              },
                              child: const Icon(Icons.call, color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Active call controls (Mute, Speaker, Dialpad, Hangup)
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isMuted ? Icons.mic_off : Icons.mic,
                                  color: isMuted ? Colors.red : Colors.white,
                                  size: 30,
                                ),
                                onPressed: () {
                                  context.read<CallControlBloc>().add(const ToggleMuteEvent());
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  isSpeaker ? Icons.volume_up : Icons.volume_down,
                                  color: isSpeaker ? Colors.green : Colors.white,
                                  size: 30,
                                ),
                                onPressed: () {
                                  context.read<CallControlBloc>().add(const ToggleSpeakerEvent());
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.dialpad,
                                  color: _showDialpad ? Colors.amber : Colors.white,
                                  size: 30,
                                ),
                                onPressed: () {
                                  setState(() => _showDialpad = !_showDialpad);
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 48.0),
                        child: FloatingActionButton.large(
                          heroTag: 'hangup_btn',
                          backgroundColor: Colors.red,
                          onPressed: () {
                            context.read<CallControlBloc>().add(const TerminateCallEvent());
                          },
                          child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                        ),
                      ),
                    ],
                  ],
                ),
                // Dialpad overlay
                if (_showDialpad)
                  Positioned(
                    bottom: 140,
                    left: 24,
                    right: 24,
                    child: InCallDialpad(
                      onDigitPressed: (digit) {
                        context.read<CallControlBloc>().add(SendDTMFEvent(digit));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
