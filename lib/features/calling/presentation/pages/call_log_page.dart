import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_log_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/widgets/call_log_tile.dart';

class CallLogPage extends StatefulWidget {
  const CallLogPage({super.key});

  @override
  State<CallLogPage> createState() => _CallLogPageState();
}

class _CallLogPageState extends State<CallLogPage> {
  @override
  void initState() {
    super.initState();
    context.read<CallLogBloc>().add(LoadCallLogEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<CallLogBloc>().add(ClearCallLogEvent());
            },
            tooltip: 'Clear Log',
          ),
        ],
      ),
      body: BlocBuilder<CallLogBloc, CallLogState>(
        builder: (context, state) {
          if (state is CallLogLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CallLogError) {
            return Center(child: Text(state.message));
          }
          if (state is CallLogLoaded) {
            if (state.calls.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_end_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No call logs found.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: state.calls.length,
              itemBuilder: (context, index) {
                final call = state.calls[index];
                return CallLogTile(
                  call: call,
                  onCallBack: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling back ${call.to}...')),
                    );
                  },
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
