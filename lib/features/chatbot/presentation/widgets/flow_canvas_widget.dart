import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

const double kNodeWidth = 200;
const double kNodeHeight = 80;
const double kCanvasSize = 4000;
const double kPortRadius = 7;

class FlowCanvasWidget extends StatefulWidget {
  final FlowGraph graph;
  final String? firstSelectedNodeId;
  final String? secondSelectedNodeId;
  final ValueChanged<String?> onNodeSelected;
  final void Function(FlowNodeType type, Offset position) onDropNode;
  final void Function(String nodeId, Offset delta) onNodeMoved;
  final void Function(String nodeId) onNodeDelete;
  final void Function(String sourceNodeId, String targetNodeId) onEdgeCreated;
  final void Function(String edgeId) onEdgeDelete;

  const FlowCanvasWidget({
    super.key,
    required this.graph,
    required this.firstSelectedNodeId,
    required this.secondSelectedNodeId,
    required this.onNodeSelected,
    required this.onDropNode,
    required this.onNodeMoved,
    required this.onNodeDelete,
    required this.onEdgeCreated,
    required this.onEdgeDelete,
  });

  @override
  State<FlowCanvasWidget> createState() => _FlowCanvasWidgetState();
}

class _FlowCanvasWidgetState extends State<FlowCanvasWidget> {
  Offset _nodeOutputPort(FlowNode node) {
    return Offset(node.position.dx + kNodeWidth, node.position.dy + kNodeHeight / 2);
  }

  Offset _nodeInputPort(FlowNode node) {
    return Offset(node.position.dx, node.position.dy + kNodeHeight / 2);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DragTarget<FlowNodeType>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.offset);
          widget.onDropNode(details.data, local);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              border: isHovering ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.3,
              maxScale: 2.5,
              child: GestureDetector(
                onTapDown: (details) {
                  final tappedEdge = _hitTestEdge(details.localPosition);
                  if (tappedEdge != null) {
                    _showEdgeDeleteDialog(context, tappedEdge);
                    return;
                  }
                  widget.onNodeSelected(null);
                },
                child: SizedBox(
                  width: kCanvasSize,
                  height: kCanvasSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: const Size(kCanvasSize, kCanvasSize),
                        painter: _GridPainter(),
                      ),
                      CustomPaint(
                        size: const Size(kCanvasSize, kCanvasSize),
                        painter: _EdgePainter(graph: widget.graph),
                      ),
                      ...widget.graph.nodes.map((node) => _buildNodeCard(node)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNodeCard(FlowNode node) {
    final isFirst = widget.firstSelectedNodeId == node.id;
    final isSecond = widget.secondSelectedNodeId == node.id;
    final isStart = node.nodeType == FlowNodeType.start;
    final color = _nodeColor(node.nodeType);

    Color borderColor = color.withAlpha(153);
    double borderWidth = 1.5;
    if (isFirst) {
      borderColor = Colors.blue;
      borderWidth = 2.5;
    } else if (isSecond) {
      borderColor = Colors.purple;
      borderWidth = 2.5;
    }

    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        onTap: () => widget.onNodeSelected(node.id),
        onPanUpdate: (details) {
          widget.onNodeMoved(node.id, details.delta);
        },
        child: SizedBox(
          width: kNodeWidth,
          height: kNodeHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Node card
              Container(
                width: kNodeWidth,
                height: kNodeHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_nodeIcon(node.nodeType), size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            _nodeLabel(node.nodeType),
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _nodePreview(node),
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Input port (left)
              Positioned(
                left: -kPortRadius,
                top: kNodeHeight / 2 - kPortRadius,
                child: Container(
                  width: kPortRadius * 2,
                  height: kPortRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
              // Output port (right)
              Positioned(
                right: -kPortRadius,
                top: kNodeHeight / 2 - kPortRadius,
                child: Container(
                  width: kPortRadius * 2,
                  height: kPortRadius * 2,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              // Selection badge
              if (isFirst || isSecond)
                Positioned(
                  top: -10,
                  left: -10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isFirst ? Colors.blue : Colors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isFirst ? '1' : '2',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              // Delete button (first selected, non-start)
              if (isFirst && !isStart)
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => widget.onNodeDelete(node.id),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _hitTestEdge(Offset tapPoint) {
    for (final edge in widget.graph.edges) {
      final sourceNode = widget.graph.nodes.firstWhere(
        (n) => n.id == edge.sourceNodeId,
        orElse: () => widget.graph.nodes.first,
      );
      final targetNode = widget.graph.nodes.firstWhere(
        (n) => n.id == edge.targetNodeId,
        orElse: () => widget.graph.nodes.first,
      );
      final p1 = _nodeOutputPort(sourceNode);
      final p4 = _nodeInputPort(targetNode);
      if (_isNearBezier(tapPoint, p1, p4, threshold: 8)) {
        return edge.id;
      }
    }
    return null;
  }

  bool _isNearBezier(Offset point, Offset p1, Offset p4, {double threshold = 8}) {
    final p2 = Offset(p1.dx + 100, p1.dy);
    final p3 = Offset(p4.dx - 100, p4.dy);
    // Sample points along the bezier curve
    for (int i = 0; i <= 20; i++) {
      final t = i / 20.0;
      final bx = _bezier(t, p1.dx, p2.dx, p3.dx, p4.dx);
      final by = _bezier(t, p1.dy, p2.dy, p3.dy, p4.dy);
      final dist = math.sqrt(math.pow(point.dx - bx, 2) + math.pow(point.dy - by, 2));
      if (dist <= threshold) return true;
    }
    return false;
  }

  double _bezier(double t, double p0, double p1, double p2, double p3) {
    final mt = 1 - t;
    return mt * mt * mt * p0 + 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t * p3;
  }

  void _showEdgeDeleteDialog(BuildContext context, String edgeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Edge'),
        content: const Text('Are you sure you want to delete this connection?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEdgeDelete(edgeId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _nodeColor(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.start:
        return Colors.green;
      case FlowNodeType.message:
        return Colors.blue;
      case FlowNodeType.question:
        return Colors.purple;
      case FlowNodeType.quickReply:
        return Colors.teal;
      case FlowNodeType.listMessage:
        return Colors.indigo;
      case FlowNodeType.condition:
        return Colors.orange;
      case FlowNodeType.action:
        return Colors.amber.shade700;
      case FlowNodeType.end:
        return Colors.red;
    }
  }

  IconData _nodeIcon(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.start:
        return Icons.play_circle_outline;
      case FlowNodeType.message:
        return Icons.chat_bubble_outline;
      case FlowNodeType.question:
        return Icons.help_outline;
      case FlowNodeType.quickReply:
        return Icons.reply_outlined;
      case FlowNodeType.listMessage:
        return Icons.list_alt_outlined;
      case FlowNodeType.condition:
        return Icons.call_split_outlined;
      case FlowNodeType.action:
        return Icons.bolt_outlined;
      case FlowNodeType.end:
        return Icons.stop_circle_outlined;
    }
  }

  String _nodeLabel(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.start:
        return 'Start';
      case FlowNodeType.message:
        return 'Message';
      case FlowNodeType.question:
        return 'Question';
      case FlowNodeType.quickReply:
        return 'Quick Reply';
      case FlowNodeType.listMessage:
        return 'List Message';
      case FlowNodeType.condition:
        return 'Condition';
      case FlowNodeType.action:
        return 'Action';
      case FlowNodeType.end:
        return 'End';
    }
  }

  String _nodePreview(FlowNode node) {
    switch (node.nodeType) {
      case FlowNodeType.start:
        return 'Entry point';
      case FlowNodeType.message:
        return node.data['text'] ?? 'No text';
      case FlowNodeType.question:
        return node.data['text'] ?? 'No question';
      case FlowNodeType.quickReply:
        final buttons = node.data['buttons'] as List?;
        return buttons != null ? '${buttons.length} button(s)' : 'No buttons';
      case FlowNodeType.listMessage:
        final items = node.data['items'] as List?;
        return items != null ? '${items.length} item(s)' : 'No items';
      case FlowNodeType.condition:
        final rules = node.data['rules'] as List?;
        return rules != null ? '${rules.length} rule(s)' : 'No rules';
      case FlowNodeType.action:
        return node.data['subType'] ?? 'No sub-type';
      case FlowNodeType.end:
        return 'End conversation';
    }
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _EdgePainter extends CustomPainter {
  final FlowGraph graph;

  _EdgePainter({required this.graph});

  Offset _outputPort(FlowNode node) =>
      Offset(node.position.dx + kNodeWidth, node.position.dy + kNodeHeight / 2);

  Offset _inputPort(FlowNode node) =>
      Offset(node.position.dx, node.position.dy + kNodeHeight / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.blueGrey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in graph.edges) {
      final sourceNode = _findNode(edge.sourceNodeId);
      final targetNode = _findNode(edge.targetNodeId);
      if (sourceNode == null || targetNode == null) continue;

      final p1 = _outputPort(sourceNode);
      final p4 = _inputPort(targetNode);
      final p2 = Offset(p1.dx + 100, p1.dy);
      final p3 = Offset(p4.dx - 100, p4.dy);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p2.dx, p2.dy, p3.dx, p3.dy, p4.dx, p4.dy);
      canvas.drawPath(path, edgePaint);

      _drawArrow(canvas, p3, p4, edgePaint);

      // Draw edge label at midpoint of the bezier curve
      if (edge.edgeLabel != null && edge.edgeLabel!.isNotEmpty) {
        final mid = _bezierPoint(0.5, p1, p2, p3, p4);
        _drawEdgeLabel(canvas, edge.edgeLabel!, mid);
      }
    }
  }

  Offset _bezierPoint(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final mt = 1 - t;
    final x = mt * mt * mt * p0.dx + 3 * mt * mt * t * p1.dx + 3 * mt * t * t * p2.dx + t * t * t * p3.dx;
    final y = mt * mt * mt * p0.dy + 3 * mt * mt * t * p1.dy + 3 * mt * t * t * p2.dy + t * t * t * p3.dy;
    return Offset(x, y);
  }

  void _drawEdgeLabel(Canvas canvas, String label, Offset center) {
    const padding = 6.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: textPainter.width + padding * 2,
        height: textPainter.height + padding,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.blueGrey.shade600,
    );

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 8.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrowSize * math.cos(angle - math.pi / 6),
        to.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..lineTo(
        to.dx - arrowSize * math.cos(angle + math.pi / 6),
        to.dy - arrowSize * math.sin(angle + math.pi / 6),
      )
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  FlowNode? _findNode(String id) {
    try {
      return graph.nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => true;
}
