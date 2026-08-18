import 'dart:ui';

enum FlowNodeType {
  start,
  message,
  question,
  quickReply,
  listMessage,
  condition,
  action,
  end,
  // ── Catalog / Commerce nodes ──────────────────────────────────────────────
  catalogMessage,
  singleProduct,
  multiProduct,
  productCarousel;

  static FlowNodeType fromString(String value) {
    final lower = value.toLowerCase();
    switch (lower) {
      case 'start':
        return FlowNodeType.start;
      case 'message':
        return FlowNodeType.message;
      case 'question':
        return FlowNodeType.question;
      case 'quickreply':
      case 'quick_reply':
        return FlowNodeType.quickReply;
      case 'listmessage':
      case 'list_message':
        return FlowNodeType.listMessage;
      case 'condition':
        return FlowNodeType.condition;
      case 'action':
        return FlowNodeType.action;
      case 'end':
        return FlowNodeType.end;
      case 'catalogmessage':
      case 'catalog_message':
        return FlowNodeType.catalogMessage;
      case 'singleproduct':
      case 'single_product':
        return FlowNodeType.singleProduct;
      case 'multiproduct':
      case 'multi_product':
        return FlowNodeType.multiProduct;
      case 'productcarousel':
      case 'product_carousel':
        return FlowNodeType.productCarousel;
      default:
        throw FlowParseException('Unknown node type: $value');
    }
  }

  String toJsonString() {
    switch (this) {
      case FlowNodeType.start:
        return 'start';
      case FlowNodeType.message:
        return 'message';
      case FlowNodeType.question:
        return 'question';
      case FlowNodeType.quickReply:
        return 'quickReply';
      case FlowNodeType.listMessage:
        return 'listMessage';
      case FlowNodeType.condition:
        return 'condition';
      case FlowNodeType.action:
        return 'action';
      case FlowNodeType.end:
        return 'end';
      case FlowNodeType.catalogMessage:
        return 'catalogMessage';
      case FlowNodeType.singleProduct:
        return 'singleProduct';
      case FlowNodeType.multiProduct:
        return 'multiProduct';
      case FlowNodeType.productCarousel:
        return 'productCarousel';
    }
  }
}

class FlowParseException implements Exception {
  final String message;
  FlowParseException(this.message);

  @override
  String toString() => 'FlowParseException: $message';
}

class FlowNode {
  final String id;
  final FlowNodeType nodeType;
  final Offset position;
  final Map<String, dynamic> data;

  FlowNode({
    required this.id,
    required this.nodeType,
    required this.position,
    required this.data,
  });

  /// Convenience getter for the string representation of the node type.
  String get type => nodeType.toJsonString();

  factory FlowNode.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) throw FlowParseException('Node missing required field: id');
    if (json['type'] == null) throw FlowParseException('Node missing required field: type');

    final posJson = json['position'];
    if (posJson == null) throw FlowParseException('Node missing required field: position');

    final x = (posJson['x'] as num?)?.toDouble() ?? 0.0;
    final y = (posJson['y'] as num?)?.toDouble() ?? 0.0;

    return FlowNode(
      id: json['id'] as String,
      nodeType: FlowNodeType.fromString(json['type'] as String),
      position: Offset(x, y),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': nodeType.toJsonString(),
      'position': {'x': position.dx, 'y': position.dy},
      'data': data,
    };
  }
}

class FlowEdge {
  final String id;
  final String sourceNodeId;
  final String sourcePort;
  final String targetNodeId;
  final String targetPort;
  final String? edgeLabel;

  FlowEdge({
    required this.id,
    required this.sourceNodeId,
    required this.sourcePort,
    required this.targetNodeId,
    required this.targetPort,
    this.edgeLabel,
  });

  factory FlowEdge.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) throw FlowParseException('Edge missing required field: id');
    if (json['sourceNodeId'] == null) throw FlowParseException('Edge missing required field: sourceNodeId');
    if (json['targetNodeId'] == null) throw FlowParseException('Edge missing required field: targetNodeId');

    return FlowEdge(
      id: json['id'] as String,
      sourceNodeId: json['sourceNodeId'] as String,
      sourcePort: json['sourcePort'] as String? ?? 'output',
      targetNodeId: json['targetNodeId'] as String,
      targetPort: json['targetPort'] as String? ?? 'input',
      edgeLabel: json['edgeLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceNodeId': sourceNodeId,
      'sourcePort': sourcePort,
      'targetNodeId': targetNodeId,
      'targetPort': targetPort,
      if (edgeLabel != null) 'edgeLabel': edgeLabel,
    };
  }
}

class FlowGraph {
  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  FlowGraph({required this.nodes, required this.edges});

  factory FlowGraph.fromJson(Map<String, dynamic> json) {
    if (json['nodes'] == null) throw FlowParseException('Flow missing required field: nodes');
    if (json['edges'] == null) throw FlowParseException('Flow missing required field: edges');

    if (json['nodes'] is! List) throw FlowParseException('Flow field "nodes" must be an array');
    if (json['edges'] is! List) throw FlowParseException('Flow field "edges" must be an array');

    try {
      final nodes = (json['nodes'] as List)
          .map((n) => FlowNode.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList();
      final edges = (json['edges'] as List)
          .map((e) => FlowEdge.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return FlowGraph(nodes: nodes, edges: edges);
    } on FlowParseException {
      rethrow;
    } catch (e) {
      throw FlowParseException('Malformed flow JSON: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  /// Validates the flow graph and returns a list of error messages.
  /// An empty list means the flow is valid.
  List<String> validate() {
    final errors = <String>[];

    // Check that a Start node exists
    final hasStart = nodes.any((n) => n.nodeType == FlowNodeType.start);
    if (!hasStart) {
      errors.add('Flow must have a Start node.');
    }

    // Build a set of source node IDs that have at least one outgoing edge
    final nodesWithOutgoing = edges.map((e) => e.sourceNodeId).toSet();

    for (final node in nodes) {
      // Every non-End node must have at least one outgoing edge
      if (node.nodeType != FlowNodeType.end) {
        if (!nodesWithOutgoing.contains(node.id)) {
          errors.add('Node "${node.id}" (${node.type}) has no outgoing edge.');
        }
      }

      // Quick Reply: buttons list must have 1–3 items
      if (node.nodeType == FlowNodeType.quickReply) {
        final buttons = node.data['buttons'];
        if (buttons == null || buttons is! List) {
          errors.add('Quick Reply node "${node.id}" must have a buttons list.');
        } else if (buttons.isEmpty || buttons.length > 3) {
          errors.add(
            'Quick Reply node "${node.id}" must have between 1 and 3 buttons (found ${buttons.length}).',
          );
        }
      }

      // List Message: items list must have 1–10 items
      if (node.nodeType == FlowNodeType.listMessage) {
        final items = node.data['items'];
        if (items == null || items is! List) {
          errors.add('List Message node "${node.id}" must have an items list.');
        } else if (items.isEmpty || items.length > 10) {
          errors.add(
            'List Message node "${node.id}" must have between 1 and 10 items (found ${items.length}).',
          );
        }
      }

      // Message node: data['text'] must not be empty
      if (node.nodeType == FlowNodeType.message) {
        final text = node.data['text'];
        if (text == null || (text as String).trim().isEmpty) {
          errors.add('Message node "${node.id}" must have a non-empty text field.');
        }
      }

      // Question node: data['text'] or data['question'] must not be empty
      if (node.nodeType == FlowNodeType.question) {
        final text = node.data['text'];
        final question = node.data['question'];
        final hasText = text != null && (text as String).trim().isNotEmpty;
        final hasQuestion = question != null && (question as String).trim().isNotEmpty;
        if (!hasText && !hasQuestion) {
          errors.add('Question node "${node.id}" must have a non-empty text or question field.');
        }
      }
      // Catalog Message node: must have non-empty body
      if (node.nodeType == FlowNodeType.catalogMessage) {
        final body = node.data['body'];
        if (body == null || (body as String).trim().isEmpty) {
          errors.add('Catalog Message node "${node.id}" must have a non-empty body field.');
        }
      }

      // Single Product node: must have catalogId and productRetailerId
      if (node.nodeType == FlowNodeType.singleProduct) {
        final catId = node.data['catalogId'];
        final prodId = node.data['productRetailerId'];
        if (catId == null || (catId as String).trim().isEmpty) {
          errors.add('Single Product node "${node.id}" must have a catalogId.');
        }
        if (prodId == null || (prodId as String).trim().isEmpty) {
          errors.add('Single Product node "${node.id}" must have a productRetailerId.');
        }
      }

      // Multi-Product node: must have catalogId and at least 1 section with 1 product
      if (node.nodeType == FlowNodeType.multiProduct) {
        final catId = node.data['catalogId'];
        if (catId == null || (catId as String).trim().isEmpty) {
          errors.add('Multi-Product node "${node.id}" must have a catalogId.');
        }
        final sections = node.data['sections'];
        if (sections == null ||
            sections is! List ||
            sections.isEmpty) {
          errors.add('Multi-Product node "${node.id}" must have at least one section.');
        } else {
          final hasProduct = sections.any((s) {
            final items = (s as Map)['productItems'];
            return items is List && items.isNotEmpty;
          });
          if (!hasProduct) {
            errors.add('Multi-Product node "${node.id}" must have at least one product in a section.');
          }
        }
      }

      // Product Carousel node: must have catalogId and 2–10 cards
      if (node.nodeType == FlowNodeType.productCarousel) {
        final catId = node.data['catalogId'];
        if (catId == null || (catId as String).trim().isEmpty) {
          errors.add('Product Carousel node "${node.id}" must have a catalogId.');
        }
        final cards = node.data['cards'];
        if (cards == null || cards is! List) {
          errors.add('Product Carousel node "${node.id}" must have a cards list.');
        } else if ((cards as List).length < 2 || cards.length > 10) {
          errors.add(
            'Product Carousel node "${node.id}" must have between 2 and 10 cards (found ${cards.length}).',
          );
        }
      }
    }

    return errors;
  }
}
