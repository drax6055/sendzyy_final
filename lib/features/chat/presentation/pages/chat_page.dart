import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  String _searchQuery = '';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.animateTo(
          _messagesScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatLoaded) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        if (state is ChatInitial) {
          context.read<ChatBloc>().add(FetchConversations());
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ChatLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ChatLoaded) {
          return Row(
            children: [
              // 1. Conversation Sidebar
              _buildConversationSidebar(state),

              // 2. Chat Window
              Expanded(
                child: state.selectedContactId == null
                    ? _buildEmptyState()
                    : _buildChatWindow(state),
              ),
            ],
          );
        }

        return const Center(child: Text('Something went wrong.'));
      },
    );
  }

  Widget _buildConversationSidebar(ChatLoaded state) {
    final filtered = _searchQuery.isEmpty
        ? state.conversations
        : state.conversations.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final number = (c['id'] as String? ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || number.contains(q);
          }).toList();

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by Name or Number......',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No conversations found',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final bool isSelected =
                          state.selectedContactId == conv['id'];
                      final DateTime lastActive = conv['lastActive'] is DateTime
                          ? (conv['lastActive'] as DateTime).toLocal()
                          : (DateTime.tryParse(
                                      conv['lastActive']?.toString() ?? '',
                                    ) ??
                                    DateTime.now())
                                .toLocal();
                      final bool isWithin24h =
                          DateTime.now().difference(lastActive).inHours < 24;

                      return ListTile(
                        onTap: () => context.read<ChatBloc>().add(
                          SelectConversation(conv['id']),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppTheme.primaryColor.withOpacity(
                          0.05,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.secondaryColor,
                          child: Text(
                            (conv['name'] as String?)?.isNotEmpty == true
                                ? conv['name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                conv['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(lastActive),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                conv['lastMessage'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 24h Indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isWithin24h
                                    ? Colors.green
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Select a conversation to start chatting',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildChatWindow(ChatLoaded state) {
    final contact = state.conversations.firstWhere(
      (c) => c['id'] == state.selectedContactId,
    );
    final DateTime lastActive = contact['lastActive'] is DateTime
        ? (contact['lastActive'] as DateTime).toLocal()
        : (DateTime.tryParse(contact['lastActive']?.toString() ?? '') ??
                  DateTime.now())
              .toLocal();
    final bool isWithin24h = DateTime.now().difference(lastActive).inHours < 24;

    return SelectionArea(
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor,
                  child: Text(
                    (contact['name'] as String?)?.isNotEmpty == true
                        ? contact['name'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          contact['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          contact['id'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 99, 99, 99),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWithin24h ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isWithin24h
                              ? '24h Window Open'
                              : '24h Window Expired (Requires Template)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (isWithin24h) _WindowTimerWidget(lastActive: lastActive),
              ],
            ),
          ),

          // Messages Areas
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: const EdgeInsets.all(24),
              child: ListView.builder(
                controller: _messagesScrollController,
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
          ),

          // Input Area
          _buildInputArea(state.selectedContactId!, isWithin24h),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bloc = context.read<ChatBloc>();
    return MessageRenderer(
      msg: msg,
      maxWidth: MediaQuery.of(context).size.width * 0.4,
      formatTime: _formatMessageTime,
      baseUrl: AppConstants.baseUrl,
      authToken: bloc.authToken,
    );
  }

  Widget _buildInputArea(String contactId, bool isWithin24h) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: isWithin24h
          ? Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                  onPressed: () => _showAttachmentMenu(context, contactId),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(contactId),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  onPressed: () => _handleSend(contactId),
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'The 24-hour conversation window has expired. You can only send templates to this customer.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _handleSend(String contactId) {
    if (_messageController.text.trim().isNotEmpty) {
      context.read<ChatBloc>().add(
        SendMessage(contactId, _messageController.text.trim()),
      );
      _messageController.clear();
    }
  }

  void _showAttachmentMenu(BuildContext context, String contactId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Attachment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attachmentOption(
                      icon: Icons.image,
                      color: Colors.purple,
                      label: 'Image\n(Max 5MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'image',
                          extensions: ['jpg', 'jpeg', 'png'],
                          maxSize: 5 * 1024 * 1024,
                        );
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.videocam,
                      color: Colors.pink,
                      label: 'Video\n(Max 16MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'video',
                          extensions: ['mp4', '3gp'],
                          maxSize: 16 * 1024 * 1024,
                        );
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.audiotrack,
                      color: Colors.orange,
                      label: 'Audio\n(Max 16MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'audio',
                          extensions: ['aac', 'mp3', 'amr', 'ogg'],
                          maxSize: 16 * 1024 * 1024,
                        );
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.insert_drive_file,
                      color: Colors.blue,
                      label: 'Document\n(Max 100MB)',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'document',
                          extensions: [], // Allow all extensions
                          maxSize: 100 * 1024 * 1024,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendAttachment({
    required String contactId,
    required String type,
    required List<String> extensions,
    required int maxSize,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Validate size
      if (file.size > maxSize) {
        final mbLimit = (maxSize / (1024 * 1024)).toStringAsFixed(0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File exceeds the max size limit of $mbLimit MB for ${type}s.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      bool isDialogShowing = false;
      if (mounted) {
        isDialogShowing = true;
        _showSendingOverlay(context, file.name);
      }

      final chatBloc = context.read<ChatBloc>();
      final mediaId = await chatBloc.uploadMedia(file);

      if (isDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mediaId.isNotEmpty) {
        chatBloc.add(
          SendMediaMessage(
            contactId: contactId,
            mediaId: mediaId,
            type: type,
            filename: type == 'document' ? file.name : null,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${type[0].toUpperCase()}${type.substring(1)} sent successfully.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to upload media to server.');
      }
    } catch (e) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        // Safe check to close dialog if still open on exception
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send attachment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSendingOverlay(BuildContext context, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'Sending "$fileName"...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Converts any DateTime to IST (UTC+5:30) and returns HH:mm
  String _formatDate(DateTime date) {
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    return "${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}";
  }

  // Resolves message time from msg['time'] (ISO/formatted string) or msg['timestamp'] (ISO string)
  String _formatMessageTime(Map<String, dynamic> msg) {
    if (msg['time'] != null) {
      final timeStr = msg['time'].toString();
      final parsed = DateTime.tryParse(timeStr);
      if (parsed != null) return _formatDate(parsed);
      // If it's already a formatted time string (e.g., "19:21"), return it directly
      return timeStr;
    }
    if (msg['timestamp'] != null) {
      final parsed = DateTime.tryParse(msg['timestamp'].toString());
      if (parsed != null) return _formatDate(parsed);
    }
    return '';
  }
}

/// Renders a single message bubble, dispatching on [msg]['messageType'] to
/// show the appropriate content (text, template, image, video, etc.).
class MessageRenderer extends StatelessWidget {
  final Map<String, dynamic> msg;
  final double maxWidth;
  final String Function(Map<String, dynamic>) formatTime;

  /// Base URL of the backend server (used to construct media proxy URLs).
  final String? baseUrl;

  /// JWT auth token for authenticated media requests.
  final String? authToken;

  const MessageRenderer({
    super.key,
    required this.msg,
    required this.maxWidth,
    required this.formatTime,
    this.baseUrl,
    this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMe = msg['isMe'] == true;
    final String? messageType = msg['messageType'] as String?;
    final String? source = msg['source'] as String?;
    final bool isChatbotMsg = source != null;
    // Bot messages = isMe true from chatbot; Customer chatbot replies = isMe false with source set
    final bool isBotSent = isChatbotMsg && isMe;

    // Chatbot bot-sent messages use a distinct teal background to differentiate from tenant messages
    final Color bubbleColor = isBotSent
        ? const Color(0xFF00897B) // teal-700 for bot messages
        : (isMe ? AppTheme.primaryColor : Colors.white);

    Widget bubble = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildContent(context, isMe, messageType, isBotSent: isBotSent),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTime(msg),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(context),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 🤖 Bot label above chatbot messages
              if (isChatbotMsg)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        isBotSent ? 'Chatbot' : 'Chatbot Reply',
                        style: TextStyle(
                          fontSize: 10,
                          color: isBotSent
                              ? const Color(0xFF00897B)
                              : Colors.deepPurple.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              bubble,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final status = msg['status'] as String? ?? 'sent';
    final errorDetails = msg['errorDetails'] as String?;

    if (status == 'failed') {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Message Delivery Failed'),
                ],
              ),
              content: Text(
                errorDetails ??
                    'Meta processing error. Please choose a different file or check your configuration.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        child: Tooltip(
          message: 'Delivery Failed. Tap for details.',
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(1.5),
            child: Icon(Icons.error, color: Colors.red.shade600, size: 14),
          ),
        ),
      );
    } else if (status == 'read') {
      return const Icon(
        Icons.done_all,
        color: Color.fromARGB(255, 28, 85, 31),
        size: 16,
      );
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all, color: Colors.white, size: 16);
    } else {
      return const Icon(Icons.done, color: Colors.white, size: 16);
    }
  }

  Widget _buildContent(BuildContext context, bool isMe, String? messageType, {bool isBotSent = false}) {
    final textColor = isMe ? Colors.white : AppTheme.secondaryColor;
    final mutedColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade500;

    switch (messageType) {
      case 'template':
        final templateBody = msg['templateBody'] as String?;
        final templateName = msg['templateName'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 14, color: mutedColor),
                const SizedBox(width: 4),
                Text(
                  'Template',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              templateBody ??
                  (templateName != null
                      ? '📋 Template: $templateName'
                      : '📋 Template'),
              style: TextStyle(color: textColor),
            ),
          ],
        );

      case 'image':
        final mediaUrl = msg['mediaUrl'] as String?;
        if (mediaUrl != null) {
          return _ImageBubble(
            mediaId: mediaUrl,
            isMe: isMe,
            baseUrl: baseUrl,
            authToken: authToken,
          );
        }
        return _iconLabel(
          Icons.image_outlined,
          '📷 Image',
          textColor,
          mutedColor,
        );

      case 'video':
        final videoMediaId = msg['mediaUrl'] as String?;
        if (videoMediaId != null && baseUrl != null && authToken != null) {
          return _VideoBubble(
            mediaId: videoMediaId,
            isMe: isMe,
            baseUrl: baseUrl!,
            authToken: authToken!,
          );
        }
        return _iconLabel(
          Icons.play_circle_outline,
          '🎥 Video',
          textColor,
          mutedColor,
        );

      case 'audio':
      case 'voice':
        final audioMediaId = msg['mediaUrl'] as String?;
        if (audioMediaId != null && baseUrl != null && authToken != null) {
          return _AudioBubble(
            mediaId: audioMediaId,
            isMe: isMe,
            baseUrl: baseUrl!,
            authToken: authToken!,
          );
        }
        return _iconLabel(
          Icons.graphic_eq,
          '🎵 Audio message',
          textColor,
          mutedColor,
        );

      case 'document':
        final docText = msg['text'] as String?;
        return _iconLabel(
          Icons.insert_drive_file_outlined,
          docText != null && docText.isNotEmpty ? '📄 $docText' : '📄 Document',
          textColor,
          mutedColor,
        );

      case 'sticker':
        return Text(
          '😊 Sticker',
          style: TextStyle(color: textColor, fontSize: 24),
        );

      case 'location':
        final locText = msg['text'] as String?;
        return _iconLabel(
          Icons.location_on_outlined,
          locText != null && locText.isNotEmpty ? '📍 $locText' : '📍 Location',
          textColor,
          mutedColor,
        );

      case 'interactive':
        final payload = msg['interactivePayload'] as Map<String, dynamic>?;
        final interactiveType = payload?['type'] as String? ?? '';

        // Bot-sent interactive: outbound quick-reply buttons or list message from chatbot
        if (isBotSent && payload != null) {
          if (interactiveType == 'button') {
            return _buildBotButtonOptions(payload, textColor, mutedColor);
          } else if (interactiveType == 'list') {
            return _buildBotListOptions(payload, textColor, mutedColor);
          }
        }

        // Customer interactive reply (button_reply / list_reply)
        final replyTitle = payload?['title'] as String? ?? '';
        final replyIcon = interactiveType == 'list_reply'
            ? Icons.list_alt_outlined
            : Icons.touch_app_outlined;
        final replyLabel = interactiveType == 'list_reply' ? 'List Reply' : 'Button Reply';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(replyIcon, size: 14, color: mutedColor),
                const SizedBox(width: 4),
                Text(
                  replyLabel,
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(replyTitle, style: TextStyle(color: textColor)),
          ],
        );

      case 'button':
        final buttonText = msg['text'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 14, color: mutedColor),
                const SizedBox(width: 4),
                Text(
                  'Button Reply',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(buttonText, style: TextStyle(color: textColor)),
          ],
        );

      case 'reaction':
        final emoji = msg['text'] as String? ?? '👍';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 6),
            Text('Reaction', style: TextStyle(fontSize: 12, color: mutedColor)),
          ],
        );

      case 'contacts':
        final contactText = msg['text'] as String? ?? '';
        final parts = contactText.split('|');
        final name = parts[0].isNotEmpty ? parts[0] : 'Contact';
        final phone = parts.length > 1 ? parts[1] : '';

        return Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.teal.shade800.withOpacity(0.3) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe ? Colors.teal.shade700.withOpacity(0.5) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty) ...[
                const Divider(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied contact number "$phone" to clipboard.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: isMe ? Colors.white : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy Phone',
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe ? Colors.white : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

      case 'unsupported':
        return Text(
          '⚠️ Unsupported message type',
          style: TextStyle(color: mutedColor, fontStyle: FontStyle.italic),
        );

      // 'text', null (legacy), or any unknown type — plain text fallback
      default:
        return Text(
          msg['text'] as String? ?? '',
          style: TextStyle(color: textColor),
        );
    }
  }

  Widget _iconLabel(
    IconData icon,
    String label,
    Color textColor,
    Color iconColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor)),
      ],
    );
  }

  /// Renders a bot-sent quick-reply message: shows the question text + button option pills.
  Widget _buildBotButtonOptions(
    Map<String, dynamic> payload,
    Color textColor,
    Color mutedColor,
  ) {
    final questionText = payload['title'] as String? ?? '';
    final buttons =
        (payload['buttons'] as List<dynamic>? ?? []).map((b) {
      return (b as Map<String, dynamic>)['label'] as String? ?? '';
    }).where((l) => l.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (questionText.isNotEmpty) ...[
          Text(questionText, style: TextStyle(color: textColor)),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: buttons.map((label) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Renders a bot-sent list message: shows the question text + list item rows.
  Widget _buildBotListOptions(
    Map<String, dynamic> payload,
    Color textColor,
    Color mutedColor,
  ) {
    final questionText = payload['title'] as String? ?? '';
    final buttonLabel = payload['buttonLabel'] as String? ?? 'View Options';
    final items = (payload['items'] as List<dynamic>? ?? []).map((item) {
      final m = item as Map<String, dynamic>;
      return {'title': m['title'] as String? ?? '', 'description': m['description'] as String? ?? ''};
    }).where((i) => (i['title'] as String).isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (questionText.isNotEmpty) ...[
          Text(questionText, style: TextStyle(color: textColor)),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list_alt, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      buttonLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if ((item['description'] as String).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item['description']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (i < items.length - 1)
                      const Divider(height: 1, color: Colors.white12),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
} // end MessageRenderer

/// Loads a customer-sent image via the backend media proxy.
/// Tapping opens a full-screen preview dialog.
/// Falls back to a label if the image fails to load.
class _ImageBubble extends StatelessWidget {
  final String mediaId;
  final bool isMe;
  final String? baseUrl;
  final String? authToken;

  const _ImageBubble({
    required this.mediaId,
    required this.isMe,
    this.baseUrl,
    this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : AppTheme.secondaryColor;
    final iconColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade500;

    if (baseUrl == null || authToken == null) {
      return _fallback(textColor, iconColor);
    }

    final url = '$baseUrl/media/$mediaId';

    return GestureDetector(
      onTap: () => _showImagePreview(context, url),
      child: Image.network(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
        width: 200,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            return _fallback(textColor, iconColor);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _fallback(textColor, iconColor),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                headers: {'Authorization': 'Bearer $authToken'},
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(Color textColor, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text('📷 Image', style: TextStyle(color: textColor)),
      ],
    );
  }
}

/// Shows a native browser audio player using an <audio> HTML element.
/// The audio is streamed from the backend media proxy.
class _AudioBubble extends StatefulWidget {
  final String mediaId;
  final bool isMe;
  final String baseUrl;
  final String authToken;

  const _AudioBubble({
    required this.mediaId,
    required this.isMe,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'audio-player-${widget.mediaId}';
    _registerAudioElement();
  }

  void _registerAudioElement() {
    final audioUrl =
        '${widget.baseUrl}/media/${widget.mediaId}?token=${widget.authToken}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final audio = html.AudioElement()
        ..src = audioUrl
        ..controls = true
        ..style.width = '100%'
        ..style.height = '40px'
        ..style.outline = 'none';
      return audio;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 48,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

/// Shows a video thumbnail with a play button overlay.
/// Uses a hidden <video> element to render the first frame as a preview.
/// Tapping opens the video in a new browser tab.
class _VideoBubble extends StatefulWidget {
  final String mediaId;
  final bool isMe;
  final String baseUrl;
  final String authToken;

  const _VideoBubble({
    required this.mediaId,
    required this.isMe,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late final String _videoUrl;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _videoUrl =
        '${widget.baseUrl}/media/${widget.mediaId}?token=${widget.authToken}';
    _viewId = 'video-thumb-${widget.mediaId}';
    _registerVideoElement();
  }

  void _registerVideoElement() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final video = html.VideoElement()
        ..src = _videoUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '8px'
        ..preload = 'metadata'
        ..muted = true;
      // Seek to first frame so the poster shows
      video.onLoadedMetadata.listen((_) {
        video.currentTime = 0.1;
      });
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: () => html.window.open(_videoUrl, '_blank'),
      child: SizedBox(
        width: 200,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: HtmlElementView(viewType: _viewId),
            ),
            // Dark overlay + play icon
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: iconColor,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowTimerWidget extends StatefulWidget {
  final DateTime lastActive;

  const _WindowTimerWidget({required this.lastActive});

  @override
  State<_WindowTimerWidget> createState() => _WindowTimerWidgetState();
}

class _WindowTimerWidgetState extends State<_WindowTimerWidget> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  @override
  void didUpdateWidget(_WindowTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastActive != widget.lastActive) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final expiry = widget.lastActive.add(const Duration(hours: 24));
    final remaining = expiry.difference(now);
    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off_outlined,
              size: 16,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              'Expired',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_outlined,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$hours:$minutes:$seconds',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
