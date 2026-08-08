import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/templates/data/models/assistant_exception.dart';
import 'package:iFloraBuzz/features/templates/data/models/generated_template.dart';
import 'package:iFloraBuzz/features/templates/data/services/template_assistant_service.dart';

// ---------------------------------------------------------------------------
// Data class for quick-action chips
// ---------------------------------------------------------------------------
class _QuickChip {
  final String key;
  final String label;
  final String instruction;
  const _QuickChip(this.key, this.label, this.instruction);
}

// ---------------------------------------------------------------------------
// AssistantDialog
// ---------------------------------------------------------------------------
class AssistantDialog extends StatefulWidget {
  final void Function(String body, String? header, String? footer) onApply;

  /// Current content already typed in the form — used to pre-fill the prompt
  /// and populate the "Before" comparison panel.
  final String? initialHeader;
  final String? initialBody;
  final String? initialFooter;
  final String? category;

  const AssistantDialog({
    super.key,
    required this.onApply,
    this.initialHeader,
    this.initialBody,
    this.initialFooter,
    this.category,
  });

  @override
  State<AssistantDialog> createState() => _AssistantDialogState();
}

class _AssistantDialogState extends State<AssistantDialog> {
  static const int _maxChars = 500;

  final _promptController = TextEditingController();
  final _service = TemplateAssistantService();

  int _charCount = 0;
  bool _isLoading = false;
  GeneratedTemplate? _result;
  String? _errorMessage;
  bool _isKeyNotConfigured = false;
  String? _selectedChipKey;

  /// The formatted original content derived from the form controllers.
  String _baseContent = '';

  // ── Quick-action chips ────────────────────────────────────────────────────
  static const List<_QuickChip> _chips = [
    _QuickChip(
      'marketing',
      '✨ Convert to Marketing',
      'Convert this to a WhatsApp Marketing template with an engaging, promotional tone',
    ),
    _QuickChip(
      'utility',
      '🔧 Convert to Utility',
      'Convert this to a WhatsApp Utility template that is informational and transactional',
    ),
    _QuickChip(
      'professional',
      '💼 Make Professional',
      'Rewrite this template in a formal, professional business tone',
    ),
    _QuickChip(
      'conversational',
      '💬 Make Conversational',
      'Rewrite this template in a friendly, conversational tone',
    ),
    _QuickChip(
      'concise',
      '✏️ Make Concise',
      'Rewrite this template more concisely without losing key information',
    ),
    _QuickChip(
      'rephrase',
      '🔁 Rephrase',
      'Rephrase this template while keeping the same meaning and tone',
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _buildBaseContent();
  }

  /// Formats the pre-existing form content into a readable prompt string.
  void _buildBaseContent() {
    final parts = <String>[];
    final header = widget.initialHeader?.trim() ?? '';
    final body = widget.initialBody?.trim() ?? '';
    final footer = widget.initialFooter?.trim() ?? '';

    if (header.isNotEmpty) parts.add('Header: $header');
    if (body.isNotEmpty) parts.add('Body: $body');
    if (footer.isNotEmpty) parts.add('Footer: $footer');

    _baseContent = parts.join('\n');
    if (_baseContent.isNotEmpty) {
      _promptController.text = _baseContent;
      _charCount = _baseContent.length;
    }
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    setState(() {
      _charCount = _promptController.text.length;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool get _hasOriginalContent {
    final header = widget.initialHeader?.trim() ?? '';
    final body = widget.initialBody?.trim() ?? '';
    final footer = widget.initialFooter?.trim() ?? '';
    return header.isNotEmpty || body.isNotEmpty || footer.isNotEmpty;
  }

  bool get _canSend =>
      !_isLoading && _charCount > 0 && _charCount <= _maxChars;

  // ── Chip interaction ──────────────────────────────────────────────────────
  void _onChipTap(String key, String instruction) {
    setState(() {
      if (_selectedChipKey == key) {
        // Deselect: revert to base content
        _selectedChipKey = null;
        _promptController.text = _baseContent;
      } else {
        _selectedChipKey = key;
        final combined = _baseContent.isNotEmpty
            ? '$instruction:\n\n$_baseContent'
            : instruction;
        final capped = combined.length > _maxChars
            ? combined.substring(0, _maxChars)
            : combined;
        _promptController.text = capped;
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
      }
    });
  }

  // ── AI call ───────────────────────────────────────────────────────────────
  Future<void> _onSend() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
      _isKeyNotConfigured = false;
    });

    try {
      final result = await _service.generateTemplate(
        prompt,
        category: widget.category,
      );
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on AssistantException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isKeyNotConfigured = e.isKeyNotConfigured;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isKeyNotConfigured = false;
        _isLoading = false;
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _onApply() {
    if (_result == null) return;
    widget.onApply(_result!.body, _result!.header, _result!.footer);
    Navigator.of(context).pop();
  }

  void _onKeepOriginal() => Navigator.of(context).pop();

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showComparison = _result != null && _hasOriginalContent;
    final maxWidth = showComparison ? 860.0 : 540.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF5F7FA),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPromptInput(),
                    const SizedBox(height: 10),
                    _buildChipRow(),
                    const SizedBox(height: 14),
                    _buildSendButton(),
                    if (_isLoading) ...[
                      const SizedBox(height: 20),
                      _buildLoadingIndicator(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorSection(),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 20),
                      showComparison
                          ? _buildBeforeAfterComparison()
                          : _buildResultOnly(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.15),
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Template Assistant',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Text(
                  'Refine your content or let AI draft it from scratch',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  // ── Prompt input ──────────────────────────────────────────────────────────
  Widget _buildPromptInput() {
    final isOverLimit = _charCount > _maxChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _promptController,
          maxLines: 4,
          minLines: 3,
          enabled: !_isLoading,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Describe your template or use a quick action below…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: isOverLimit
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isOverLimit ? Colors.red : AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasOriginalContent)
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Pre-filled from your form',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            Row(
              children: [
                if (isOverLimit)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Max 500 chars',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverLimit
                        ? Colors.red.shade600
                        : Colors.grey.shade500,
                    fontWeight: isOverLimit
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Chip row ──────────────────────────────────────────────────────────────
  Widget _buildChipRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade400,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _chips.map((chip) {
              final isSelected = _selectedChipKey == chip.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => _onChipTap(chip.key, chip.instruction),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      chip.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Send button ───────────────────────────────────────────────────────────
  Widget _buildSendButton() {
    return ElevatedButton.icon(
      onPressed: _canSend ? _onSend : null,
      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(_isLoading ? 'Generating…' : 'Generate with AI'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade400,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor),
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'AI is crafting your template…',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorSection() {
    if (_isKeyNotConfigured) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_off_outlined,
                color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Please configure your OpenAI API key in Integration Settings to use the AI assistant.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                  fontSize: 13, color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  // ── Before / After comparison ─────────────────────────────────────────────
  Widget _buildBeforeAfterComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section title bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Choose which version to use',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Before & After',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Two-column cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBeforeCard()),
            const SizedBox(width: 14),
            Expanded(child: _buildAfterCard()),
          ],
        ),
      ],
    );
  }

  /// When there's no original content, just show the AI result card.
  Widget _buildResultOnly() {
    return _buildAfterCard();
  }

  // ── Before card ───────────────────────────────────────────────────────────
  Widget _buildBeforeCard() {
    final header = widget.initialHeader?.trim() ?? '';
    final body = widget.initialBody?.trim() ?? '';
    final footer = widget.initialFooter?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Before  (Current)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header.isNotEmpty) ...[
                  _buildFieldLabel('HEADER'),
                  const SizedBox(height: 4),
                  Text(
                    header,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFieldLabel('BODY'),
                const SizedBox(height: 4),
                Text(
                  body.isNotEmpty ? body : '(empty)',
                  style: TextStyle(
                    fontSize: 14,
                    color: body.isNotEmpty
                        ? Colors.black87
                        : Colors.grey.shade400,
                    fontStyle: body.isNotEmpty
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildFieldLabel('FOOTER'),
                  const SizedBox(height: 4),
                  Text(
                    footer,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Action button
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _onKeepOriginal,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Keep Original'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black54,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── After card ────────────────────────────────────────────────────────────
  Widget _buildAfterCard() {
    final header = _result!.header?.trim() ?? '';
    final body = _result!.body.trim();
    final footer = _result!.footer?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.12),
                  AppTheme.primaryColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'After  (AI Generated)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 10, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header.isNotEmpty) ...[
                  _buildFieldLabel('HEADER'),
                  const SizedBox(height: 4),
                  Text(
                    header,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFieldLabel('BODY'),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87),
                ),
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildFieldLabel('FOOTER'),
                  const SizedBox(height: 4),
                  Text(
                    footer,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Action button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _onApply,
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Use This'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 42),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade400,
        letterSpacing: 1,
      ),
    );
  }
}
