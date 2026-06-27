import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/action_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/condition_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/end_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/list_message_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/message_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/question_node_form.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_forms/quick_reply_node_form.dart';

class PropertiesPanelWidget extends StatelessWidget {
  final FlowNode? selectedNode;
  final ValueChanged<Map<String, dynamic>> onNodeDataChanged;

  const PropertiesPanelWidget({
    super.key,
    required this.selectedNode,
    required this.onNodeDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              selectedNode == null ? 'Properties' : _nodeTypeLabel(selectedNode!.nodeType),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildForm(),
            ),
          ),
        ],
      ),
    );
  }

  String _nodeTypeLabel(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.start:
        return 'Start Node';
      case FlowNodeType.message:
        return 'Message Node';
      case FlowNodeType.question:
        return 'Question Node';
      case FlowNodeType.quickReply:
        return 'Quick Reply Node';
      case FlowNodeType.listMessage:
        return 'List Message Node';
      case FlowNodeType.condition:
        return 'Condition Node';
      case FlowNodeType.action:
        return 'Action Node';
      case FlowNodeType.end:
        return 'End Node';
    }
  }

  Widget _buildForm() {
    if (selectedNode == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Icon(Icons.touch_app_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Select a node to edit',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final node = selectedNode!;

    switch (node.nodeType) {
      case FlowNodeType.start:
        return Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, color: Colors.green.shade600),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Start node — entry point of the flow.'),
                ),
              ],
            ),
          ),
        );
      case FlowNodeType.message:
        return MessageNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.question:
        return QuestionNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.quickReply:
        return QuickReplyNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.listMessage:
        return ListMessageNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.condition:
        return ConditionNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.action:
        return ActionNodeForm(node: node, onChanged: onNodeDataChanged);
      case FlowNodeType.end:
        return const EndNodeForm();
    }
  }
}
