import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/instagram/data/models/instagram_comment_models.dart';

class InstagramCommentDialog extends StatefulWidget {
  final InstagramCommentAutomation? existing;
  final Future<void> Function(
    String name,
    String postSelectionType,
    List<InstagramMediaItem> selectedMedia,
    String triggerType,
    List<String> keywords,
    bool sendPublicReply,
    String publicReplyMessage,
    bool sendPrivateDm,
    String privateDmMessage,
  ) onSave;

  const InstagramCommentDialog({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<InstagramCommentDialog> createState() => _InstagramCommentDialogState();
}

class _InstagramCommentDialogState extends State<InstagramCommentDialog> {
  final _formKey = GlobalKey<FormState>();
  final Dio _dio = getIt<Dio>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _keywordCtrl;
  late final TextEditingController _publicReplyCtrl;
  late final TextEditingController _privateDmCtrl;

  String _postSelectionType = 'all'; // 'all' | 'specific'
  List<InstagramMediaItem> _selectedMedia = [];

  String _triggerType = 'keyword'; // 'keyword' | 'all'
  List<String> _keywords = [];

  bool _sendPublicReply = true;
  bool _sendPrivateDm = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _keywordCtrl = TextEditingController();
    _publicReplyCtrl = TextEditingController(text: e?.publicReplyMessage ?? 'Thanks! Check your DM 📩');
    _privateDmCtrl = TextEditingController(
      text: e?.privateDmMessage ?? 'Hi {{username}}! Thanks for your interest. Here are the details you requested!',
    );

    _postSelectionType = e?.postSelectionType ?? 'all';
    _selectedMedia = List<InstagramMediaItem>.from(e?.selectedMedia ?? []);

    _triggerType = e?.triggerType ?? 'keyword';
    _keywords = List<String>.from(e?.triggerKeywords ?? []);

    _sendPublicReply = e?.sendPublicReply ?? true;
    _sendPrivateDm = e?.sendPrivateDm ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keywordCtrl.dispose();
    _publicReplyCtrl.dispose();
    _privateDmCtrl.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _keywordCtrl.text.trim().toLowerCase();
    if (kw.isEmpty) return;
    if (_keywords.contains(kw)) {
      _keywordCtrl.clear();
      return;
    }
    setState(() {
      _keywords.add(kw);
      _keywordCtrl.clear();
    });
  }

  Future<void> _openMediaPicker() async {
    final chosenMedia = await showDialog<List<InstagramMediaItem>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MediaPickerDialog(
        dio: _dio,
        initialSelected: _selectedMedia,
      ),
    );

    if (chosenMedia != null && mounted) {
      setState(() {
        _selectedMedia = chosenMedia;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_postSelectionType == 'specific' && _selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one Post or Reel')),
      );
      return;
    }

    if (_triggerType == 'keyword' && _keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one trigger keyword')),
      );
      return;
    }

    if (!_sendPublicReply && !_sendPrivateDm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable at least Public Reply or Private DM')),
      );
      return;
    }

    if (_sendPrivateDm && _privateDmCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private DM message cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        _nameCtrl.text.trim(),
        _postSelectionType,
        _selectedMedia,
        _triggerType,
        _keywords,
        _sendPublicReply,
        _publicReplyCtrl.text.trim(),
        _sendPrivateDm,
        _privateDmCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.forum_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEdit ? 'Edit Comment Automation' : 'New Comment Automation',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Automatically reply to Instagram comments and send private DMs',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Automation Name
                      _buildSectionHeader(
                        icon: Icons.label_outline_rounded,
                        title: '1. Automation Name',
                        subtitle: 'Give this rule a descriptive label for internal tracking',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco(
                          'e.g. Price Inquiry Bot, Giveaway Reel DM, Discount Code Trigger',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Automation name is required' : null,
                      ),
                      const SizedBox(height: 24),

                      // 2. Post / Reel Selection
                      _buildSectionHeader(
                        icon: Icons.movie_filter_rounded,
                        title: '2. Target Posts & Reels',
                        subtitle: 'Choose whether this rule applies to all posts or specific selected posts/reels',
                      ),
                      const SizedBox(height: 10),
                      _buildPostSelectionSection(),
                      const SizedBox(height: 24),

                      // 3. Comment Trigger Type
                      _buildSectionHeader(
                        icon: Icons.bolt_rounded,
                        title: '3. Comment Trigger Condition',
                        subtitle: 'When should this automation fire?',
                      ),
                      const SizedBox(height: 10),
                      _buildTriggerTypeSection(),
                      const SizedBox(height: 24),

                      // 4. Public Reply
                      _buildSectionHeader(
                        icon: Icons.reply_rounded,
                        title: '4. Public Comment Reply (Optional)',
                        subtitle: 'Leave an instant reply directly under the user\'s comment on Instagram',
                      ),
                      const SizedBox(height: 10),
                      _buildPublicReplySection(),
                      const SizedBox(height: 24),

                      // 5. Private DM Message
                      _buildSectionHeader(
                        icon: Icons.send_rounded,
                        title: '5. Private Direct Message (DM)',
                        subtitle: 'Sent automatically to the user\'s Instagram Direct Message inbox',
                      ),
                      const SizedBox(height: 10),
                      _buildPrivateDmSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Update Automation' : 'Save Automation',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Post Selection Section ────────────────────────────────────────────────
  Widget _buildPostSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _radioCard(
                  title: 'All Posts & Reels',
                  subtitle: 'Triggers on every existing & future post or reel',
                  icon: Icons.auto_awesome_motion_rounded,
                  selected: _postSelectionType == 'all',
                  onTap: () => setState(() => _postSelectionType = 'all'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _radioCard(
                  title: 'Selected Post / Reel',
                  subtitle: 'Triggers only on specific posts or reels you choose',
                  icon: Icons.filter_center_focus_rounded,
                  selected: _postSelectionType == 'specific',
                  onTap: () => setState(() => _postSelectionType = 'specific'),
                ),
              ),
            ],
          ),
          if (_postSelectionType == 'specific') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Posts/Reels (${_selectedMedia.length}):',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openMediaPicker,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: Text(_selectedMedia.isEmpty ? 'Select Posts/Reels' : 'Change Selection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _selectedMedia.map((media) {
                  return Container(
                    width: 190,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: media.displayImageUrl.isNotEmpty
                              ? Image.network(
                                  media.displayImageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image_rounded, size: 20),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.purple.shade50,
                                  child: Icon(
                                    media.isReel ? Icons.play_circle_rounded : Icons.image_rounded,
                                    color: Colors.purple,
                                    size: 24,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: media.isReel ? Colors.red.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  media.isReel ? 'REEL' : 'POST',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: media.isReel ? Colors.red.shade700 : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                media.caption.isNotEmpty ? media.caption : 'No caption',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: Colors.grey.shade500,
                          onPressed: () {
                            setState(() {
                              _selectedMedia.removeWhere((m) => m.id == media.id);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No post selected yet. Click "Select Posts/Reels" to pick from your Instagram profile.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Trigger Type Section ───────────────────────────────────────────────────
  Widget _buildTriggerTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _radioCard(
                  title: 'Specific Keywords',
                  subtitle: 'Fires when comment contains words like "price", "link", "info"',
                  icon: Icons.tag_rounded,
                  selected: _triggerType == 'keyword',
                  onTap: () => setState(() => _triggerType = 'keyword'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _radioCard(
                  title: 'Every Comment',
                  subtitle: 'Fires on any comment regardless of text',
                  icon: Icons.all_inclusive_rounded,
                  selected: _triggerType == 'all',
                  onTap: () => setState(() => _triggerType = 'all'),
                ),
              ),
            ],
          ),
          if (_triggerType == 'keyword') ...[
            const SizedBox(height: 16),
            Text(
              'Trigger Keywords (press Enter or click Add):',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordCtrl,
                    decoration: _inputDeco('Type a keyword e.g. price, link, send, demo, discount'),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addKeyword,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_keywords.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _keywords.map((kw) {
                  return Chip(
                    label: Text(kw, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.purple.shade50,
                    labelStyle: TextStyle(color: Colors.purple.shade800),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    deleteIconColor: Colors.purple.shade700,
                    onDeleted: () => setState(() => _keywords.remove(kw)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.purple.shade200),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Text(
                'No keywords added yet. Please add at least one trigger keyword.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Public Reply Section ───────────────────────────────────────────────────
  Widget _buildPublicReplySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Post a Public Reply to the Comment',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Directly replies to the user\'s comment on the post for all to see',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _sendPublicReply,
                onChanged: (v) => setState(() => _sendPublicReply = v),
                activeThumbColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (_sendPublicReply) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _publicReplyCtrl,
              maxLines: 2,
              decoration: _inputDeco('e.g. Thanks @{{username}}! Check your DM for details 📩'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Tip: {{username}} will be replaced by the commenter\'s handle.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final cur = _publicReplyCtrl.text;
                    _publicReplyCtrl.text = '$cur {{username}}'.trim();
                  },
                  icon: const Icon(Icons.alternate_email_rounded, size: 14),
                  label: const Text('Insert {{username}}', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Private DM Section ─────────────────────────────────────────────────────
  Widget _buildPrivateDmSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Private Direct Message (DM)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sends an automated DM with links, pricing, or instructions to their inbox',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _sendPrivateDm,
                onChanged: (v) => setState(() => _sendPrivateDm = v),
                activeThumbColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (_sendPrivateDm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _privateDmCtrl,
              maxLines: 4,
              decoration: _inputDeco(
                'Hi {{username}}! Thanks for checking out our post. Here is the link you requested: https://yourlink.com',
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Supports {{username}} variable.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final cur = _privateDmCtrl.text;
                    _privateDmCtrl.text = '$cur {{username}}'.trim();
                  },
                  icon: const Icon(Icons.alternate_email_rounded, size: 14),
                  label: const Text('Insert {{username}}', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppTheme.primaryColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: selected ? AppTheme.primaryColor : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: selected ? AppTheme.primaryColor : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Media Picker Dialog ───────────────────────────────────────────────────────
class _MediaPickerDialog extends StatefulWidget {
  final Dio dio;
  final List<InstagramMediaItem> initialSelected;

  const _MediaPickerDialog({
    required this.dio,
    required this.initialSelected,
  });

  @override
  State<_MediaPickerDialog> createState() => _MediaPickerDialogState();
}

class _MediaPickerDialogState extends State<_MediaPickerDialog> {
  bool _isLoading = true;
  String? _error;
  List<InstagramMediaItem> _items = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelected.map((m) => m.id));
    _fetchMedia();
  }

  Future<void> _fetchMedia() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch user posts and reels via backend route
      final res = await widget.dio.get('/api/instagram/comment-automations/media');
      if (mounted && res.data != null) {
        final rawList = res.data['data'] as List? ?? [];
        final parsed = rawList.map((m) {
          return InstagramMediaItem.fromJson(Map<String, dynamic>.from(m as Map));
        }).toList();

        setState(() {
          _items = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Instagram Posts & Reels',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose one or multiple posts/reels to connect to this automation',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to fetch Instagram posts:\n$_error',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchMedia,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FaIcon(FontAwesomeIcons.instagram, size: 40, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No posts or reels found on your connected Instagram account.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please upload a post/reel to your Instagram or switch to "All Posts & Reels".',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final isSelected = _selectedIds.contains(item.id);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(item.id);
                                      } else {
                                        _selectedIds.add(item.id);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Image thumbnail with badge & selection check
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                                  child: item.displayImageUrl.isNotEmpty
                                                      ? Image.network(
                                                          item.displayImageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => Container(
                                                            color: Colors.grey.shade100,
                                                            child: const Center(
                                                              child: Icon(Icons.broken_image_rounded, size: 32),
                                                            ),
                                                          ),
                                                        )
                                                      : Container(
                                                          color: Colors.purple.shade50,
                                                          child: Center(
                                                            child: Icon(
                                                              item.isReel ? Icons.play_circle_rounded : Icons.image_rounded,
                                                              color: Colors.purple,
                                                              size: 40,
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              // Reel / Media badge
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        item.isReel ? Icons.play_arrow_rounded : Icons.photo_rounded,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.isReel ? 'REEL' : 'POST',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Selection checkmark badge
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.8),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: isSelected
                                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Caption
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            item.caption.isNotEmpty ? item.caption : 'No caption',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11.5, height: 1.2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedIds.length} item(s) selected',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final selectedObjects = _items.where((item) => _selectedIds.contains(item.id)).toList();
                        Navigator.pop(context, selectedObjects);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Confirm Selection'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
