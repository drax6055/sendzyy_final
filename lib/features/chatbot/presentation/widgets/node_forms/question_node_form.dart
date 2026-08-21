import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class QuestionNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const QuestionNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<QuestionNodeForm> createState() => _QuestionNodeFormState();
}

class _QuestionNodeFormState extends State<QuestionNodeForm> {
  late TextEditingController _textController;
  late List<Map<String, String>> _keywords;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.node.data['text'] ?? '');
    _keywords = _parseKeywords(widget.node.data['keywords']);
  }

  @override
  void didUpdateWidget(QuestionNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _textController.text = widget.node.data['text'] ?? '';
      _keywords = _parseKeywords(widget.node.data['keywords']);
    }
  }

  List<Map<String, String>> _parseKeywords(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw.map<Map<String, String>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {'keyword': m['keyword']?.toString() ?? '', 'edgeLabel': m['edgeLabel']?.toString() ?? ''};
    }).toList();
  }

  void _notify() {
    widget.onChanged({
      ...widget.node.data,
      'text': _textController.text,
      'keywords': _keywords.map((k) => Map<String, dynamic>.from(k)).toList(),
    });
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
        const Text('Question Text', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter question...',
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Keyword Routes', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () {
                setState(() => _keywords.add({'keyword': '', 'edgeLabel': ''}));
                _notify();
              },
            ),
          ],
        ),
        ..._keywords.asMap().entries.map((entry) {
          final i = entry.key;
          final kw = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: kw['keyword'])
                      ..selection = TextSelection.collapsed(offset: kw['keyword']!.length),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Keyword',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() => _keywords[i]['keyword'] = v);
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: kw['edgeLabel'])
                      ..selection = TextSelection.collapsed(offset: kw['edgeLabel']!.length),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Edge Label',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() => _keywords[i]['edgeLabel'] = v);
                      _notify();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() => _keywords.removeAt(i));
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
