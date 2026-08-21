import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class ListMessageNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const ListMessageNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<ListMessageNodeForm> createState() => _ListMessageNodeFormState();
}

class _ListMessageNodeFormState extends State<ListMessageNodeForm> {
  late TextEditingController _sectionTitleController;
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _sectionTitleController = TextEditingController(text: widget.node.data['sectionTitle'] ?? '');
    _items = _parseItems(widget.node.data['items']);
  }

  @override
  void didUpdateWidget(ListMessageNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _sectionTitleController.text = widget.node.data['sectionTitle'] ?? '';
      _items = _parseItems(widget.node.data['items']);
    }
  }

  List<Map<String, String>> _parseItems(dynamic raw) {
    if (raw == null || raw is! List) return [{'title': '', 'description': ''}];
    return raw.map<Map<String, String>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {
        'title': m['title']?.toString() ?? '',
        'description': m['description']?.toString() ?? '',
      };
    }).toList();
  }

  void _notify() {
    widget.onChanged({
      ...widget.node.data,
      'sectionTitle': _sectionTitleController.text,
      'items': _items.map((item) => Map<String, dynamic>.from(item)).toList(),
    });
  }

  @override
  void dispose() {
    _sectionTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Section Title', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _sectionTitleController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. Choose an option',
            isDense: true,
          ),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Items (1–10)', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _items.length >= 10
                  ? null
                  : () {
                      setState(() => _items.add({'title': '', 'description': ''}));
                      _notify();
                    },
            ),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: item['title'])
                            ..selection = TextSelection.collapsed(offset: item['title']!.length),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Title',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setState(() => _items[i]['title'] = v);
                            _notify();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                        onPressed: _items.length <= 1
                            ? null
                            : () {
                                setState(() => _items.removeAt(i));
                                _notify();
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: item['description'])
                      ..selection = TextSelection.collapsed(offset: item['description']!.length),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Description (optional)',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() => _items[i]['description'] = v);
                      _notify();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
