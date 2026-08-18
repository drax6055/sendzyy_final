import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class NodePaletteWidget extends StatelessWidget {
  const NodePaletteWidget({super.key});

  static const _paletteItems = [
    _PaletteItem(
      type: FlowNodeType.message,
      label: 'Message',
      icon: Icons.chat_bubble_outline,
      color: Colors.blue,
    ),
    _PaletteItem(
      type: FlowNodeType.question,
      label: 'Question',
      icon: Icons.help_outline,
      color: Colors.purple,
    ),
    _PaletteItem(
      type: FlowNodeType.quickReply,
      label: 'Quick Reply',
      icon: Icons.reply_outlined,
      color: Colors.teal,
    ),
    _PaletteItem(
      type: FlowNodeType.listMessage,
      label: 'List Message',
      icon: Icons.list_alt_outlined,
      color: Colors.indigo,
    ),
    _PaletteItem(
      type: FlowNodeType.condition,
      label: 'Condition',
      icon: Icons.call_split_outlined,
      color: Colors.orange,
    ),
    _PaletteItem(
      type: FlowNodeType.action,
      label: 'Action',
      icon: Icons.bolt_outlined,
      color: Colors.amber,
    ),
    _PaletteItem(
      type: FlowNodeType.catalogMessage,
      label: 'Catalog Msg',
      icon: Icons.storefront_outlined,
      color: Color(0xFF25D366),
    ),
    _PaletteItem(
      type: FlowNodeType.singleProduct,
      label: 'Single Product',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF06B6D4),
    ),
    _PaletteItem(
      type: FlowNodeType.multiProduct,
      label: 'Multi Product',
      icon: Icons.grid_view_outlined,
      color: Color(0xFF6366F1),
    ),
    _PaletteItem(
      type: FlowNodeType.productCarousel,
      label: 'Carousel',
      icon: Icons.view_carousel_outlined,
      color: Color(0xFF7C3AED),
    ),
    _PaletteItem(
      type: FlowNodeType.end,
      label: 'End',
      icon: Icons.stop_circle_outlined,
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
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
              'Node Palette',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: _paletteItems
                  .map((item) => _DraggableTile(item: item))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem {
  final FlowNodeType type;
  final String label;
  final IconData icon;
  final Color color;

  const _PaletteItem({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _DraggableTile extends StatelessWidget {
  final _PaletteItem item;

  const _DraggableTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color: item.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    return Draggable<FlowNodeType>(
      data: item.type,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 160, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }
}
