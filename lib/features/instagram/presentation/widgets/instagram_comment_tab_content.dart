import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/instagram/data/models/instagram_comment_models.dart';

class InstagramCommentTabContent extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<InstagramCommentAutomation> automations;
  final bool isConnected;
  final ValueChanged<InstagramCommentAutomation> onToggle;
  final ValueChanged<InstagramCommentAutomation> onEdit;
  final ValueChanged<InstagramCommentAutomation> onDelete;
  final VoidCallback onCreateNew;
  final VoidCallback onRetry;

  const InstagramCommentTabContent({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.automations,
    required this.isConnected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateNew,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flow info guide card
        _buildFlowInfoCard(),
        const SizedBox(height: 24),

        // Content
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            ),
          )
        else if (errorMessage != null)
          _buildErrorState()
        else if (automations.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: automations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _CommentAutomationCard(
              automation: automations[i],
              onEdit: () => onEdit(automations[i]),
              onDelete: () => onDelete(automations[i]),
              onToggle: () => onToggle(automations[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildFlowInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5), // Light purple
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1BEE7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, color: Colors.purple.shade700, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How Comments Automation Works',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                _flowStep(
                  '1',
                  'Instagram user comments on your Post or Reel (all posts or selected post).',
                ),
                _flowStep(
                  '2',
                  'Sendzyy captures the Comment Webhook (Comment ID, text, username, media ID).',
                ),
                _flowStep(
                  '3',
                  'Matches active automation rule by post/reel ID and trigger keyword.',
                ),
                _flowStep(
                  '4',
                  'Posts an instant Public Reply under the user\'s comment (optional).',
                ),
                _flowStep(
                  '5',
                  'Automatically delivers a Private DM with details/links straight to their Instagram inbox.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.purple.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB700), Color(0xFFFF007F), Color(0xFF8000FF)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.forum_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Comment Automations Yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Convert comments on your Reels and Posts into leads by automatically\nreplying publicly and sending private DMs with links & details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Tooltip(
              message: isConnected
                  ? 'Create a new automated comment responder'
                  : 'Please connect your Instagram account first',
              child: ElevatedButton.icon(
                onPressed: isConnected ? onCreateNew : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  minimumSize: const Size(260, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  isConnected ? Icons.add_rounded : Icons.lock_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  isConnected ? 'Create Comment Automation' : 'Connect Account to Create Automation',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 40),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Failed to load comment automations',
              style: TextStyle(color: Colors.red.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 40),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comment Automation Card ───────────────────────────────────────────────────
class _CommentAutomationCard extends StatelessWidget {
  final InstagramCommentAutomation automation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _CommentAutomationCard({
    required this.automation,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: automation.isActive ? Colors.purple.shade100 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: automation.isActive ? const Color(0xFFFAF5FC) : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  child: const FaIcon(
                    FontAwesomeIcons.instagram,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        automation.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Target badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: automation.postSelectionType == 'all'
                                  ? Colors.teal.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: automation.postSelectionType == 'all'
                                    ? Colors.teal.shade200
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  automation.postSelectionType == 'all'
                                      ? Icons.all_inclusive_rounded
                                      : Icons.filter_center_focus_rounded,
                                  size: 11,
                                  color: automation.postSelectionType == 'all'
                                      ? Colors.teal.shade800
                                      : Colors.blue.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  automation.postSelectionType == 'all'
                                      ? 'All Posts & Reels'
                                      : 'Specific Posts (${automation.selectedMedia.length})',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: automation.postSelectionType == 'all'
                                        ? Colors.teal.shade800
                                        : Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Active toggle switch
                Switch(
                  value: automation.isActive,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: Colors.purple.shade600,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                // Active badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: automation.isActive ? Colors.purple.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    automation.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: automation.isActive ? Colors.purple.shade900 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Automation',
                  onPressed: onEdit,
                  color: Colors.grey.shade700,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                  tooltip: 'Delete Automation',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Specific media preview thumbnails (if specific)
                if (automation.postSelectionType == 'specific' && automation.selectedMedia.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.movie_filter_rounded, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Target Posts & Reels:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: automation.selectedMedia.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: m.displayImageUrl.isNotEmpty
                                  ? Image.network(
                                      m.displayImageUrl,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16),
                                    )
                                  : Icon(m.isReel ? Icons.play_arrow : Icons.image, size: 16),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                m.caption.isNotEmpty ? m.caption : 'Post ${m.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Trigger keywords
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comment Trigger: ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (automation.triggerType == 'all')
                      _chip('Every Comment (Any keyword)', Colors.orange)
                    else
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: automation.triggerKeywords
                              .map((k) => _chip(k, Colors.purple))
                              .toList(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Public Reply preview
                if (automation.sendPublicReply && automation.publicReplyMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.reply_rounded, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Public Comment Reply',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          automation.publicReplyMessage,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Private DM preview
                if (automation.sendPrivateDm && automation.privateDmMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF9FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.send_rounded, size: 14, color: Colors.purple.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Private Direct Message (DM)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          automation.privateDmMessage,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
