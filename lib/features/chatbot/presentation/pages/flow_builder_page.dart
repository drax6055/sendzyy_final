import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/chatbot_model.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/flow_canvas_widget.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_palette_widget.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/properties_panel_widget.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class FlowBuilderPage extends StatefulWidget {
  final ChatbotModel? chatbot;

  const FlowBuilderPage({super.key, this.chatbot});

  @override
  State<FlowBuilderPage> createState() => _FlowBuilderPageState();
}

class _FlowBuilderPageState extends State<FlowBuilderPage> {
  late FlowGraph _graph;

  // Two-step selection for connecting nodes
  String? _firstSelectedNodeId;
  String? _secondSelectedNodeId;

  // Undo/redo stacks store JSON snapshots
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndoDepth = 50;

  late TextEditingController _nameController;
  List<String> _keywords = [];
  final TextEditingController _keywordInputController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chatbot?.name ?? '');
    _keywords = List<String>.from(widget.chatbot?.triggerKeywords ?? []);

    if (widget.chatbot != null && widget.chatbot!.flow.isNotEmpty) {
      try {
        _graph = FlowGraph.fromJson(widget.chatbot!.flow);
      } catch (_) {
        _graph = _createDefaultGraph();
      }
    } else {
      _graph = _createDefaultGraph();
    }
  }

  FlowGraph _createDefaultGraph() {
    return FlowGraph(
      nodes: [
        FlowNode(
          id: 'start_${_randomId()}',
          nodeType: FlowNodeType.start,
          position: const Offset(200, 200),
          data: {},
        ),
      ],
      edges: [],
    );
  }

  String _randomId() => math.Random().nextInt(999999).toString();

  // ── Undo/Redo ──────────────────────────────────────────────────────────────

  void _captureSnapshot() {
    final snapshot = _graph.toJson();
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxUndoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _graph.toJson();
    _redoStack.add(current);
    final previous = _undoStack.removeLast();
    setState(() {
      _graph = FlowGraph.fromJson(previous);
      _firstSelectedNodeId = null;
      _secondSelectedNodeId = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _graph.toJson();
    _undoStack.add(current);
    final next = _redoStack.removeLast();
    setState(() {
      _graph = FlowGraph.fromJson(next);
      _firstSelectedNodeId = null;
      _secondSelectedNodeId = null;
    });
  }

  // ── Graph mutations ────────────────────────────────────────────────────────

  void _addNode(FlowNodeType type, Offset position) {
    _captureSnapshot();
    final node = FlowNode(
      id: '${type.toJsonString()}_${_randomId()}',
      nodeType: type,
      position: position,
      data: _defaultData(type),
    );
    setState(() {
      _graph = FlowGraph(
        nodes: [..._graph.nodes, node],
        edges: _graph.edges,
      );
      _firstSelectedNodeId = node.id;
      _secondSelectedNodeId = null;
    });
  }

  Map<String, dynamic> _defaultData(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.quickReply:
        return {'buttons': [{'label': ''}]};
      case FlowNodeType.listMessage:
        return {'sectionTitle': '', 'items': [{'title': '', 'description': ''}]};
      case FlowNodeType.action:
        return {'subType': 'assign_tag', 'tag': '', 'templateName': '', 'language': ''};
      case FlowNodeType.condition:
        return {'rules': [], 'fallbackLabel': 'false'};
      case FlowNodeType.question:
        return {'text': '', 'keywords': []};
      default:
        return {};
    }
  }

  void _moveNode(String nodeId, Offset delta) {
    final nodes = _graph.nodes.map((n) {
      if (n.id == nodeId) {
        return FlowNode(
          id: n.id,
          nodeType: n.nodeType,
          position: n.position + delta,
          data: n.data,
        );
      }
      return n;
    }).toList();
    setState(() {
      _graph = FlowGraph(nodes: nodes, edges: _graph.edges);
    });
  }

  void _deleteNode(String nodeId) {
    _captureSnapshot();
    final nodes = _graph.nodes.where((n) => n.id != nodeId).toList();
    final edges = _graph.edges
        .where((e) => e.sourceNodeId != nodeId && e.targetNodeId != nodeId)
        .toList();
    setState(() {
      _graph = FlowGraph(nodes: nodes, edges: edges);
      if (_firstSelectedNodeId == nodeId) _firstSelectedNodeId = null;
      if (_secondSelectedNodeId == nodeId) _secondSelectedNodeId = null;
    });
  }

  void _addEdge(String sourceNodeId, String targetNodeId, {String? edgeLabel}) {
    final exists = _graph.edges.any(
      (e) => e.sourceNodeId == sourceNodeId && e.targetNodeId == targetNodeId,
    );
    if (exists || sourceNodeId == targetNodeId) return;

    _captureSnapshot();
    final edge = FlowEdge(
      id: 'edge_${_randomId()}',
      sourceNodeId: sourceNodeId,
      sourcePort: edgeLabel ?? 'output',
      targetNodeId: targetNodeId,
      targetPort: 'input',
      edgeLabel: edgeLabel,
    );
    setState(() {
      _graph = FlowGraph(nodes: _graph.nodes, edges: [..._graph.edges, edge]);
    });
  }

  void _deleteEdge(String edgeId) {
    _captureSnapshot();
    final edges = _graph.edges.where((e) => e.id != edgeId).toList();
    setState(() {
      _graph = FlowGraph(nodes: _graph.nodes, edges: edges);
    });
  }

  void _updateNodeData(Map<String, dynamic> newData) {
    if (_firstSelectedNodeId == null) return;
    final nodes = _graph.nodes.map((n) {
      if (n.id == _firstSelectedNodeId) {
        return FlowNode(id: n.id, nodeType: n.nodeType, position: n.position, data: newData);
      }
      return n;
    }).toList();
    setState(() {
      _graph = FlowGraph(nodes: nodes, edges: _graph.edges);
    });
  }

  /// Called when user taps a node on the canvas
  void _onNodeSelected(String? id) {
    if (id == null) {
      setState(() {
        _firstSelectedNodeId = null;
        _secondSelectedNodeId = null;
      });
      return;
    }

    setState(() {
      if (_firstSelectedNodeId == null) {
        // First selection
        _firstSelectedNodeId = id;
        _secondSelectedNodeId = null;
      } else if (_firstSelectedNodeId == id) {
        // Tapping same node deselects
        _firstSelectedNodeId = null;
        _secondSelectedNodeId = null;
      } else {
        // Second selection
        _secondSelectedNodeId = id;
      }
    });
  }

  /// Connect the two selected nodes
  void _connectSelectedNodes() {
    if (_firstSelectedNodeId == null || _secondSelectedNodeId == null) return;

    final sourceNode = _graph.nodes.firstWhere((n) => n.id == _firstSelectedNodeId);
    final labels = _getEdgeLabels(sourceNode);

    if (labels.isEmpty) {
      _addEdge(_firstSelectedNodeId!, _secondSelectedNodeId!);
      setState(() {
        _firstSelectedNodeId = null;
        _secondSelectedNodeId = null;
      });
    } else {
      _showEdgeLabelPicker(labels);
    }
  }

  /// Returns available edge labels for a node based on its keyword/button/item routes
  List<String> _getEdgeLabels(FlowNode node) {
    switch (node.nodeType) {
      case FlowNodeType.question:
        final keywords = node.data['keywords'] as List?;
        if (keywords == null || keywords.isEmpty) return [];
        return keywords
            .map((k) => (k as Map)['edgeLabel']?.toString() ?? '')
            .where((l) => l.isNotEmpty)
            .toList();
      case FlowNodeType.condition:
        final rules = node.data['rules'] as List?;
        final labels = <String>[];
        if (rules != null) {
          for (final r in rules) {
            final l = (r as Map)['edgeLabel']?.toString() ?? '';
            if (l.isNotEmpty) labels.add(l);
          }
        }
        final fallback = node.data['fallbackLabel']?.toString() ?? '';
        if (fallback.isNotEmpty) labels.add(fallback);
        return labels;
      case FlowNodeType.quickReply:
        final buttons = node.data['buttons'] as List?;
        if (buttons == null || buttons.isEmpty) return [];
        return buttons
            .map((b) => (b as Map)['label']?.toString() ?? '')
            .where((l) => l.isNotEmpty)
            .toList();
      case FlowNodeType.listMessage:
        final items = node.data['items'] as List?;
        if (items == null || items.isEmpty) return [];
        return items
            .map((i) => (i as Map)['title']?.toString() ?? '')
            .where((l) => l.isNotEmpty)
            .toList();
      default:
        return [];
    }
  }

  void _showEdgeLabelPicker(List<String> labels) {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Which route does this connection represent?'),
            const SizedBox(height: 12),
            ...labels.map(
              (label) => ListTile(
                title: Text(label),
                leading: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => Navigator.pop(ctx, label),
              ),
            ),
            ListTile(
              title: const Text('Default / No label'),
              leading: const Icon(Icons.arrow_forward_outlined, size: 18),
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    ).then((selectedLabel) {
      if (selectedLabel == null) return; // cancelled
      _addEdge(
        _firstSelectedNodeId!,
        _secondSelectedNodeId!,
        edgeLabel: selectedLabel.isEmpty ? null : selectedLabel,
      );
      setState(() {
        _firstSelectedNodeId = null;
        _secondSelectedNodeId = null;
      });
    });
  }

  // ── Keywords chip input ────────────────────────────────────────────────────

  void _addKeyword(String kw) {
    final trimmed = kw.trim().replaceAll(',', '');
    if (trimmed.isNotEmpty && !_keywords.contains(trimmed)) {
      setState(() => _keywords.add(trimmed));
    }
    _keywordInputController.clear();
  }

  void _removeKeyword(String kw) {
    setState(() => _keywords.remove(kw));
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a chatbot name.');
      return;
    }

    final errors = _graph.validate();
    if (errors.isNotEmpty) {
      _showSnackBar('Validation errors:\n${errors.join('\n')}');
      return;
    }

    setState(() => _isSaving = true);
    final flow = _graph.toJson();

    if (widget.chatbot == null) {
      context.read<ChatbotBloc>().add(
        CreateChatbot(name: name, keywords: _keywords, flow: flow),
      );
    } else {
      context.read<ChatbotBloc>().add(
        UpdateChatbot(
          id: widget.chatbot!.id,
          fields: {'name': name, 'triggerKeywords': _keywords, 'flow': flow},
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  FlowNode? get _selectedNode {
    if (_firstSelectedNodeId == null) return null;
    try {
      return _graph.nodes.firstWhere((n) => n.id == _firstSelectedNodeId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  void _showNodePaletteBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final items = const [
          _NodeOptionItem(type: FlowNodeType.message, label: 'Message', icon: Icons.chat_bubble_outline, color: Colors.blue),
          _NodeOptionItem(type: FlowNodeType.question, label: 'Question', icon: Icons.help_outline, color: Colors.purple),
          _NodeOptionItem(type: FlowNodeType.quickReply, label: 'Quick Reply', icon: Icons.reply_outlined, color: Colors.teal),
          _NodeOptionItem(type: FlowNodeType.listMessage, label: 'List Message', icon: Icons.list_alt_outlined, color: Colors.indigo),
          _NodeOptionItem(type: FlowNodeType.condition, label: 'Condition', icon: Icons.call_split_outlined, color: Colors.orange),
          _NodeOptionItem(type: FlowNodeType.action, label: 'Action', icon: Icons.bolt_outlined, color: Colors.amber),
          // TODO: Work on this module later
          // _NodeOptionItem(type: FlowNodeType.catalogMessage, label: 'Catalog Msg', icon: Icons.storefront_outlined, color: Color(0xFF25D366)),
          // _NodeOptionItem(type: FlowNodeType.singleProduct, label: 'Single Product', icon: Icons.inventory_2_outlined, color: Color(0xFF06B6D4)),
          // _NodeOptionItem(type: FlowNodeType.multiProduct, label: 'Multi Product', icon: Icons.grid_view_outlined, color: Color(0xFF6366F1)),
          // _NodeOptionItem(type: FlowNodeType.productCarousel, label: 'Carousel', icon: Icons.view_carousel_outlined, color: Color(0xFF7C3AED)),
          _NodeOptionItem(type: FlowNodeType.end, label: 'End', icon: Icons.stop_circle_outlined, color: Colors.red),
        ];

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Flow Node',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          final offset = Offset(
                            100.0 + (_graph.nodes.length * 20),
                            100.0 + (_graph.nodes.length * 20),
                          );
                          _addNode(item.type, offset);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: item.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon, color: item.color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: item.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPropertiesBottomSheet() {
    if (_selectedNode == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Node Properties',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: PropertiesPanelWidget(
                    selectedNode: _selectedNode,
                    onNodeDataChanged: _updateNodeData,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.chatbot != null;
    final isMobile = ResponsiveHelper.isMobile(context);
    final canConnect = _firstSelectedNodeId != null && _secondSelectedNodeId != null;

    return BlocListener<ChatbotBloc, ChatbotState>(
      listener: (context, state) {
        if (!_isSaving) return;
        if (state is ChatbotLoaded) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
        } else if (state is ChatbotError) {
          setState(() => _isSaving = false);
          _showSnackBar('Error: ${state.message}');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditMode ? 'Edit Chatbot' : 'New Chatbot'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo, color: Colors.white),
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            const SizedBox(width: 4),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(isMobile ? 'Save' : 'Save Chatbot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: isMobile
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedNode != null) ...[
                    FloatingActionButton.extended(
                      heroTag: 'edit_node_properties',
                      onPressed: _showPropertiesBottomSheet,
                      backgroundColor: AppTheme.secondaryColor,
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      label: const Text('Edit Node', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FloatingActionButton.extended(
                    heroTag: 'add_flow_node',
                    onPressed: _showNodePaletteBottomSheet,
                    backgroundColor: AppTheme.primaryColor,
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Add Node', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              )
            : null,
        body: Column(
          children: [
            _buildToolbar(canConnect),
            Expanded(
              child: Row(
                children: [
                  if (!isMobile) const NodePaletteWidget(),
                  FlowCanvasWidget(
                    graph: _graph,
                    firstSelectedNodeId: _firstSelectedNodeId,
                    secondSelectedNodeId: _secondSelectedNodeId,
                    onNodeSelected: _onNodeSelected,
                    onDropNode: _addNode,
                    onNodeMoved: _moveNode,
                    onNodeDelete: _deleteNode,
                    onEdgeCreated: _addEdge,
                    onEdgeDelete: _deleteEdge,
                  ),
                  if (!isMobile)
                    PropertiesPanelWidget(
                      selectedNode: _selectedNode,
                      onNodeDataChanged: _updateNodeData,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(bool canConnect) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Chatbot Name ---> Keywords
            Row(
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Chatbot Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._keywords.map(
                          (kw) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Chip(
                              label: Text(kw, style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 12),
                              onDeleted: () => _removeKeyword(kw),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _keywordInputController,
                            decoration: const InputDecoration(
                              hintText: '+ Keyword',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onSubmitted: _addKeyword,
                            onChanged: (v) {
                              if (v.endsWith(',')) _addKeyword(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Select Node 1 ---> Select Node 2 ---> Connect
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildConnectSection(canConnect),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Chatbot name
          SizedBox(
            width: 180,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Chatbot Name',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Keywords
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._keywords.map(
                    (kw) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        label: Text(kw, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeKeyword(kw),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _keywordInputController,
                      decoration: const InputDecoration(
                        hintText: 'Add keyword + Enter',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: _addKeyword,
                      onChanged: (v) {
                        if (v.endsWith(',')) _addKeyword(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Connection status + Connect button
          _buildConnectSection(canConnect),
        ],
      ),
    );
  }

  Widget _buildConnectSection(bool canConnect) {
    final node1 = _firstSelectedNodeId != null
        ? _graph.nodes.firstWhere(
            (n) => n.id == _firstSelectedNodeId,
            orElse: () => _graph.nodes.first,
          )
        : null;
    final node2 = _secondSelectedNodeId != null
        ? _graph.nodes.firstWhere(
            (n) => n.id == _secondSelectedNodeId,
            orElse: () => _graph.nodes.first,
          )
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Node 1 chip
        _selectionChip(
          label: node1 != null ? _nodeLabel(node1.nodeType) : 'Select Node 1',
          filled: node1 != null,
          color: Colors.blue,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        ),
        // Node 2 chip
        _selectionChip(
          label: node2 != null ? _nodeLabel(node2.nodeType) : 'Select Node 2',
          filled: node2 != null,
          color: Colors.purple,
        ),
        const SizedBox(width: 8),
        // Connect button
        SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: canConnect ? _connectSelectedNodes : null,
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canConnect ? Colors.green : Colors.grey.shade300,
              foregroundColor: canConnect ? Colors.white : Colors.grey,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectionChip({
    required String label,
    required bool filled,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withAlpha(30) : Colors.grey.shade100,
        border: Border.all(
          color: filled ? color : Colors.grey.shade400,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: filled ? color : Colors.grey,
          fontWeight: filled ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  String _nodeLabel(FlowNodeType type) {
    switch (type) {
      case FlowNodeType.start: return 'Start';
      case FlowNodeType.message: return 'Message';
      case FlowNodeType.question: return 'Question';
      case FlowNodeType.quickReply: return 'Quick Reply';
      case FlowNodeType.listMessage: return 'List Message';
      case FlowNodeType.condition: return 'Condition';
      case FlowNodeType.action: return 'Action';
      case FlowNodeType.end: return 'End';
      case FlowNodeType.catalogMessage: return 'Catalog Msg';
      case FlowNodeType.singleProduct: return 'Single Product';
      case FlowNodeType.multiProduct: return 'Multi Product';
      case FlowNodeType.productCarousel: return 'Carousel';
    }
  }
}

class _NodeOptionItem {
  final FlowNodeType type;
  final String label;
  final IconData icon;
  final Color color;

  const _NodeOptionItem({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });
}
