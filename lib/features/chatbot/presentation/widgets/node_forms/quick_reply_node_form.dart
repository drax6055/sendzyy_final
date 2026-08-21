import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class QuickReplyNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const QuickReplyNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<QuickReplyNodeForm> createState() => _QuickReplyNodeFormState();
}

class _QuickReplyNodeFormState extends State<QuickReplyNodeForm> {
  late List<Map<String, String>> _buttons;

  @override
  void initState() {
    super.initState();
    _buttons = _parseButtons(widget.node.data['buttons']);
  }

  @override
  void didUpdateWidget(QuickReplyNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _buttons = _parseButtons(widget.node.data['buttons']);
    }
  }

  List<Map<String, String>> _parseButtons(dynamic raw) {
    if (raw == null || raw is! List) return [{'label': ''}];
    return raw.map<Map<String, String>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {'label': m['label']?.toString() ?? ''};
    }).toList();
  }

  void _notify() {
    widget.onChanged({
      ...widget.node.data,
      'buttons': _buttons.map((b) => Map<String, dynamic>.from(b)).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Buttons (1–3)', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _buttons.length >= 3
                  ? null
                  : () {
                      setState(() => _buttons.add({'label': ''}));
                      _notify();
                    },
            ),
          ],
        ),
        ..._buttons.asMap().entries.map((entry) {
          final i = entry.key;
          final btn = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: btn['label'])
                      ..selection = TextSelection.collapsed(offset: btn['label']!.length),
                    maxLength: 20,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Button ${i + 1} Label',
                      isDense: true,
                      counterText: '',
                    ),
                    onChanged: (v) {
                      setState(() => _buttons[i]['label'] = v);
                      _notify();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  onPressed: _buttons.length <= 1
                      ? null
                      : () {
                          setState(() => _buttons.removeAt(i));
                          _notify();
                        },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
