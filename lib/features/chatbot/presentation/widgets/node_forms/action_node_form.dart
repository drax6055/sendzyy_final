import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

class ActionNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const ActionNodeForm({super.key, required this.node, required this.onChanged});

  @override
  State<ActionNodeForm> createState() => _ActionNodeFormState();
}

class _ActionNodeFormState extends State<ActionNodeForm> {
  late String _subType;
  late TextEditingController _tagController;
  late TextEditingController _languageController;
  late TextEditingController _mediaUrlController;
  List<TextEditingController> _variableControllers = [];

  // Template dropdown state
  List<Map<String, dynamic>> _templates = [];
  String? _selectedTemplateName;
  bool _loadingTemplates = false;

  static const _subTypes = ['assign_tag', 'send_template', 'end_session'];

  @override
  void initState() {
    super.initState();
    _subType = widget.node.data['subType'] ?? 'assign_tag';
    _tagController = TextEditingController(text: widget.node.data['tag'] ?? '');
    _languageController = TextEditingController(text: widget.node.data['language'] ?? '');
    _mediaUrlController = TextEditingController(
        text: widget.node.data['mediaUrl'] ?? widget.node.data['mediaId'] ?? '');
    _selectedTemplateName = widget.node.data['templateName']?.toString().isNotEmpty == true
        ? widget.node.data['templateName']
        : null;
    if (_subType == 'send_template') _fetchTemplates();
  }

  @override
  void didUpdateWidget(ActionNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _subType = widget.node.data['subType'] ?? 'assign_tag';
      _tagController.text = widget.node.data['tag'] ?? '';
      _languageController.text = widget.node.data['language'] ?? '';
      _mediaUrlController.text = widget.node.data['mediaUrl'] ?? widget.node.data['mediaId'] ?? '';
      _selectedTemplateName = widget.node.data['templateName']?.toString().isNotEmpty == true
          ? widget.node.data['templateName']
          : null;
      if (_subType == 'send_template') {
        if (_templates.isEmpty) {
          _fetchTemplates();
        } else {
          final match = _templates.firstWhere((t) => t['name'] == _selectedTemplateName, orElse: () => {});
          _onTemplateSelected(match);
        }
      }
    }
  }

  void _initializeVariableControllers(int count) {
    // Dispose previous ones
    for (var c in _variableControllers) {
      c.dispose();
    }
    
    // Load existing variable list
    final existingVars = widget.node.data['variables'] as List<dynamic>? ?? [];
    
    _variableControllers = List.generate(count, (index) {
      final val = index < existingVars.length ? existingVars[index]?.toString() ?? '' : '';
      return TextEditingController(text: val);
    });
  }

  void _onTemplateSelected(Map<String, dynamic> template) {
    if (template.isEmpty) return;
    final components = template['components'] as List<dynamic>? ?? [];
    int bodyVariablesCount = 0;

    for (var comp in components) {
      if (comp['type'] == 'BODY') {
        final bodyText = comp['text']?.toString() ?? '';
        final regExp = RegExp(r'\{\{(\d+)\}\}');
        final matches = regExp.allMatches(bodyText);
        final uniqueIndices = matches.map((m) => m.group(1)).toSet();
        bodyVariablesCount = uniqueIndices.length;
      }
    }

    _initializeVariableControllers(bodyVariablesCount);
  }

  Future<void> _fetchTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final dio = getIt<Dio>();
      final res = await dio.get('/fetch-templates');
      if (res.statusCode == 200) {
        final list = (res.data['data'] as List<dynamic>? ?? []);
        final approved = list
            .where((t) => (t['status'] as String? ?? '').toUpperCase() == 'APPROVED')
            .where((t) => (t['category'] as String? ?? '').toUpperCase() != 'AUTHENTICATION')
            .map<Map<String, dynamic>>((t) => Map<String, dynamic>.from(t))
            .where((t) => (t['name']?.toString() ?? '').isNotEmpty)
            .toList();
        if (mounted) {
          setState(() {
            _templates = approved;
            _loadingTemplates = false;
            // Validate current selection still exists
            if (_selectedTemplateName != null &&
                !_templates.any((t) => t['name'] == _selectedTemplateName)) {
              _selectedTemplateName = null;
            } else if (_selectedTemplateName != null) {
              final match = _templates.firstWhere((t) => t['name'] == _selectedTemplateName, orElse: () => {});
              _onTemplateSelected(match);
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  void _notify() {
    final varsList = _variableControllers.map((c) => c.text).toList();
    
    // Find selected template's header format to pass mediaType
    final selectedTemplate = _templates.firstWhere(
      (t) => t['name'] == _selectedTemplateName,
      orElse: () => {},
    );
    final components = selectedTemplate['components'] as List<dynamic>? ?? [];
    String? headerFormat;
    for (var comp in components) {
      if (comp['type'] == 'HEADER') {
        final format = comp['format']?.toString().toUpperCase();
        if (['IMAGE', 'VIDEO', 'DOCUMENT'].contains(format)) {
          headerFormat = format;
        }
      }
    }

    widget.onChanged({
      ...widget.node.data,
      'subType': _subType,
      'tag': _tagController.text,
      'templateName': _selectedTemplateName ?? '',
      'language': _languageController.text,
      'mediaUrl': _mediaUrlController.text,
      'mediaType': headerFormat?.toLowerCase() ?? '',
      'variables': varsList,
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    _languageController.dispose();
    _mediaUrlController.dispose();
    for (var c in _variableControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine selected template parameters dynamically
    final selectedTemplate = _templates.firstWhere(
      (t) => t['name'] == _selectedTemplateName,
      orElse: () => {},
    );
    final components = selectedTemplate['components'] as List<dynamic>? ?? [];
    String? headerFormat;
    int bodyVariablesCount = 0;

    for (var comp in components) {
      if (comp['type'] == 'HEADER') {
        final format = comp['format']?.toString().toUpperCase();
        if (['IMAGE', 'VIDEO', 'DOCUMENT'].contains(format)) {
          headerFormat = format;
        }
      } else if (comp['type'] == 'BODY') {
        final bodyText = comp['text']?.toString() ?? '';
        final regExp = RegExp(r'\{\{(\d+)\}\}');
        final matches = regExp.allMatches(bodyText);
        final uniqueIndices = matches.map((m) => m.group(1)).toSet();
        bodyVariablesCount = uniqueIndices.length;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Action Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _subType,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _subTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '))))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _subType = v);
              if (v == 'send_template' && _templates.isEmpty) _fetchTemplates();
              _notify();
            }
          },
        ),
        const SizedBox(height: 16),
        if (_subType == 'assign_tag') ...[
          const Text('Tag Name', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. VIP',
              isDense: true,
            ),
            onChanged: (_) => _notify(),
          ),
        ],
        if (_subType == 'send_template') ...[
          const Text('Template Name', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _loadingTemplates
              ? const Center(child: SizedBox(height: 36, width: 36, child: CircularProgressIndicator(strokeWidth: 2)))
              : DropdownButtonFormField<String>(
                  value: _selectedTemplateName,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  hint: const Text('Select a template'),
                  isExpanded: true,
                  items: _templates
                      .map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(
                            value: t['name'] as String,
                            child: Text(t['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final match = _templates.firstWhere((t) => t['name'] == v, orElse: () => {});
                      setState(() {
                        _selectedTemplateName = v;
                        if (match['language'] != null) {
                          _languageController.text = match['language']!;
                        }
                      });
                      _onTemplateSelected(match);
                      _notify();
                    }
                  },
                ),
          const SizedBox(height: 12),
          const Text('Language Code', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _languageController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. en_US',
              isDense: true,
            ),
            onChanged: (_) => _notify(),
          ),
          
          // Header Media Field (if template has IMAGE/VIDEO/DOCUMENT header format)
          if (headerFormat != null) ...[
            const SizedBox(height: 12),
            Text(
              'Header Media ($headerFormat)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mediaUrlController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter $headerFormat URL or Meta Media ID',
                isDense: true,
              ),
              onChanged: (_) => _notify(),
            ),
          ],

          // Body Variables Fields
          if (bodyVariablesCount > 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Template Variables',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...List.generate(bodyVariablesCount, (index) {
              // Ensure dynamic controller bounds mapping safety
              if (index >= _variableControllers.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: _variableControllers[index],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Variable {{${index + 1}}}',
                    hintText: 'Enter value for placeholder {{${index + 1}}}',
                    isDense: true,
                  ),
                  onChanged: (_) => _notify(),
                ),
              );
            }),
          ],
        ],
        if (_subType == 'end_session')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action will end the chatbot session for the contact.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
