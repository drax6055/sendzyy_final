import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/templates/data/models/assistant_exception.dart';
import 'package:iFloraBuzz/features/templates/data/models/generated_template.dart';
import 'package:iFloraBuzz/features/templates/data/services/template_assistant_service.dart';

class AssistantDialog extends StatefulWidget {
  final void Function(String body, String? header, String? footer) onApply;

  const AssistantDialog({super.key, required this.onApply});

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

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
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

  bool get _canSend =>
      !_isLoading && _charCount > 0 && _charCount <= _maxChars;

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
      final result = await _service.generateTemplate(prompt);
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

  void _onApply() {
    if (_result == null) return;
    widget.onApply(_result!.body, _result!.header, _result!.footer);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPromptInput(),
                    const SizedBox(height: 12),
                    _buildSendButton(),
                    if (_isLoading) ...[
                      const SizedBox(height: 24),
                      _buildLoadingIndicator(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorSection(),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 16),
                      _buildResultPreview(),
                      const SizedBox(height: 12),
                      _buildApplyButton(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppTheme.primaryColor,
              size: 20,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Text(
                  'Describe your message and let AI draft it',
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
          decoration: InputDecoration(
            hintText: 'My salon is closed from Dec 25 to Jan 1',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: isOverLimit
                  ? const BorderSide(color: Colors.red, width: 1.5)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isOverLimit ? Colors.red : AppTheme.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isOverLimit)
              Expanded(
                child: Text(
                  'Prompt must be 500 characters or fewer',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ),
            Text(
              '$_charCount / $_maxChars',
              style: TextStyle(
                fontSize: 12,
                color: isOverLimit ? Colors.red.shade600 : Colors.grey.shade500,
                fontWeight:
                    isOverLimit ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return ElevatedButton.icon(
      onPressed: _canSend ? _onSend : null,
      icon: const Icon(Icons.send_rounded, size: 18),
      label: const Text('Send'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade400,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          SizedBox(height: 12),
          Text(
            'Generating template…',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

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
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Generated Template',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_result!.header != null) ...[
            _buildPreviewField('Header', _result!.header!),
            const SizedBox(height: 12),
          ],
          _buildPreviewField('Body', _result!.body),
          if (_result!.footer != null) ...[
            const SizedBox(height: 12),
            _buildPreviewField('Footer', _result!.footer!),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return ElevatedButton.icon(
      onPressed: _onApply,
      icon: const Icon(Icons.check_rounded, size: 18),
      label: const Text('Apply to Template'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
