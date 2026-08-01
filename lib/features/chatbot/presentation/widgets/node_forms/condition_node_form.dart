import 'package:flutter/material.dart';
import 'package:sendzyy/features/chatbot/data/models/flow_graph.dart';

const _operators = ['==', '!=', 'contains', 'not contains', '>', '<', 'is empty', 'is not empty'];

class ConditionNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const ConditionNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<ConditionNodeForm> createState() => _ConditionNodeFormState();
}

class _ConditionNodeFormState extends State<ConditionNodeForm> {
  late List<_Rule> _rules;
  late TextEditingController _fallbackController;

  @override
  void initState() {
    super.initState();
    _rules = _parseRules(widget.node.data['rules']);
    _fallbackController = TextEditingController(text: widget.node.data['fallbackLabel'] ?? '');
  }

  @override
  void didUpdateWidget(ConditionNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      for (final r in _rules) r.dispose();
      _rules = _parseRules(widget.node.data['rules']);
      _fallbackController.text = widget.node.data['fallbackLabel'] ?? '';
    }
  }

  List<_Rule> _parseRules(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw.map<_Rule>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _Rule(
        variable: m['variable']?.toString() ?? '',
        operator: m['operator']?.toString() ?? '==',
        value: m['value']?.toString() ?? '',
        edgeLabel: m['edgeLabel']?.toString() ?? '',
      );
    }).toList();
  }

  void _notify() {
    widget.onChanged({
      ...widget.node.data,
      'rules': _rules.map((r) => r.toMap()).toList(),
      'fallbackLabel': _fallbackController.text,
    });
  }

  @override
  void dispose() {
    for (final r in _rules) r.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'Add condition',
              onPressed: () {
                setState(() => _rules.add(_Rule(variable: '', operator: '==', value: '', edgeLabel: '')));
                _notify();
              },
            ),
          ],
        ),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No conditions yet. Tap + to add one.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ..._rules.asMap().entries.map((entry) {
          final i = entry.key;
          final rule = entry.value;
          final hideValue = rule.operator == 'is empty' || rule.operator == 'is not empty';
          return _RuleTile(
            key: ValueKey('rule_$i'),
            rule: rule,
            hideValue: hideValue,
            onChanged: () {
              setState(() {});
              _notify();
            },
            onDelete: () {
              setState(() {
                _rules[i].dispose();
                _rules.removeAt(i);
              });
              _notify();
            },
          );
        }),
        const SizedBox(height: 16),
        const Text('Fallback Edge Label', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Route taken when no condition matches',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fallbackController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. false, fallback',
            isDense: true,
          ),
          onChanged: (_) => _notify(),
        ),
      ],
    );
  }
}

class _Rule {
  final TextEditingController variableCtrl;
  String operator;
  final TextEditingController valueCtrl;
  final TextEditingController edgeLabelCtrl;

  _Rule({
    required String variable,
    required this.operator,
    required String value,
    required String edgeLabel,
  })  : variableCtrl = TextEditingController(text: variable),
        valueCtrl = TextEditingController(text: value),
        edgeLabelCtrl = TextEditingController(text: edgeLabel);

  Map<String, dynamic> toMap() => {
        'variable': variableCtrl.text,
        'operator': operator,
        'value': valueCtrl.text,
        'edgeLabel': edgeLabelCtrl.text,
      };

  void dispose() {
    variableCtrl.dispose();
    valueCtrl.dispose();
    edgeLabelCtrl.dispose();
  }
}

class _RuleTile extends StatelessWidget {
  final _Rule rule;
  final bool hideValue;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _RuleTile({
    super.key,
    required this.rule,
    required this.hideValue,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variable field
          TextField(
            controller: rule.variableCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Variable',
              hintText: 'e.g. user.verified, user.plan',
              isDense: true,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 8),
          // Operator dropdown + value field
          Row(
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  value: _operators.contains(rule.operator) ? rule.operator : '==',
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Operator',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: _operators
                      .map((op) => DropdownMenuItem(value: op, child: Text(op, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      rule.operator = v;
                      onChanged();
                    }
                  },
                ),
              ),
              if (!hideValue) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: rule.valueCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Value',
                      hintText: 'e.g. true, premium',
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Edge label + delete
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: rule.edgeLabelCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Edge Label (route name)',
                    hintText: 'e.g. true, verified',
                    isDense: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

