import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class MessageNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const MessageNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<MessageNodeForm> createState() => _MessageNodeFormState();
}

class _MessageNodeFormState extends State<MessageNodeForm> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.node.data['text'] ?? '');
  }

  @override
  void didUpdateWidget(MessageNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _textController.text = widget.node.data['text'] ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Message Text', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 6,
          maxLength: 4096,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter message text...',
          ),
          onChanged: (value) {
            widget.onChanged({...widget.node.data, 'text': value});
          },
        ),
      ],
    );
  }
}
