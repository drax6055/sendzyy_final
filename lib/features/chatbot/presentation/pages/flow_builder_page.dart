import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/chatbot_model.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/flow_canvas_widget.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/node_palette_widget.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/widgets/properties_panel_widget.dart';

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

  void _showMobilePaletteBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Add Node', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _buildMobileNodeTile(ctx, FlowNodeType.message, 'Message', Icons.chat_bubble_outline, Colors.blue),
                    _buildMobileNodeTile(ctx, FlowNodeType.question, 'Question', Icons.help_outline, Colors.purple),
                    _buildMobileNodeTile(ctx, FlowNodeType.quickReply, 'Quick Reply', Icons.reply_outlined, Colors.teal),
                    _buildMobileNodeTile(ctx, FlowNodeType.listMessage, 'List Message', Icons.list_alt_outlined, Colors.indigo),
                    _buildMobileNodeTile(ctx, FlowNodeType.condition, 'Condition', Icons.call_split_outlined, Colors.orange),
                    _buildMobileNodeTile(ctx, FlowNodeType.action, 'Action', Icons.bolt_outlined, Colors.amber),
                    _buildMobileNodeTile(ctx, FlowNodeType.end, 'End', Icons.stop_circle_outlined, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileNodeTile(BuildContext ctx, FlowNodeType type, String label, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: const Icon(Icons.add, size: 20),
      onTap: () {
        Navigator.pop(ctx);
        _addNode(type, const Offset(120, 180));
      },
    );
  }

  void _showMobilePropertiesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.65,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Node Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: PropertiesPanelWidget(
                    selectedNode: _selectedNode,
                    onNodeDataChanged: (newData) {
                      _updateNodeData(newData);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.chatbot != null;
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
          title: Text(
            isEditMode ? 'Edit Chatbot' : 'New Chatbot',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white, size: 20),
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo, color: Colors.white, size: 20),
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
                  label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return Column(
              children: [
                _buildToolbar(canConnect, isMobile),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: isMobile
                            ? FlowCanvasWidget(
                                graph: _graph,
                                firstSelectedNodeId: _firstSelectedNodeId,
                                secondSelectedNodeId: _secondSelectedNodeId,
                                onNodeSelected: _onNodeSelected,
                                onDropNode: _addNode,
                                onNodeMoved: _moveNode,
                                onNodeDelete: _deleteNode,
                                onEdgeCreated: _addEdge,
                                onEdgeDelete: _deleteEdge,
                              )
                            : Row(
                                children: [
                                  const NodePaletteWidget(),
                                  Expanded(
                                    child: FlowCanvasWidget(
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
                                  ),
                                  PropertiesPanelWidget(
                                    selectedNode: _selectedNode,
                                    onNodeDataChanged: _updateNodeData,
                                  ),
                                ],
                              ),
                      ),
                      if (isMobile) ...[
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: FloatingActionButton.extended(
                            heroTag: 'fab_palette',
                            onPressed: _showMobilePaletteBottomSheet,
                            icon: const Icon(Icons.add, color: Colors.white, size: 20),
                            label: const Text('Add Node', style: TextStyle(color: Colors.white)),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        ),
                        if (_selectedNode != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton.extended(
                              heroTag: 'fab_properties',
                              onPressed: _showMobilePropertiesBottomSheet,
                              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                              label: const Text('Properties', style: TextStyle(color: Colors.white)),
                              backgroundColor: AppTheme.secondaryColor,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar(bool canConnect, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          children: [
            // Line 1: Chatbot Name and Keyword input aligned in same row
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Chatbot Name',
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._keywords.map(
                          (kw) => Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Chip(
                              label: Text(kw, style: const TextStyle(fontSize: 10)),
                              deleteIcon: const Icon(Icons.close, size: 12),
                              onDeleted: () => _removeKeyword(kw),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _keywordInputController,
                            decoration: const InputDecoration(
                              hintText: 'Add keyword...',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            style: const TextStyle(fontSize: 12),
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
            const SizedBox(height: 6),
            // Line 2: Connection bar (Select Node 1 -> Select Node 2 -> Connect)
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
    }
  }
}