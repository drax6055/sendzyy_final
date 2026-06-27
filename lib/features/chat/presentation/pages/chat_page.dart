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
                    : Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No conversations found',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  )
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final conv = filtered[index];
                final bool isSelected = state.selectedContactId == conv['id'];
                final DateTime lastActive = conv['lastActive'] is DateTime
                    ? (conv['lastActive'] as DateTime).toLocal()
                    : (DateTime.tryParse(conv['lastActive']?.toString() ?? '') ?? DateTime.now()).toLocal();
                final bool isWithin24h =
                    DateTime.now().difference(lastActive).inHours < 24;

                return ListTile(
                  onTap: () => context.read<ChatBloc>().add(
                    SelectConversation(conv['id']),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.05),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
        : (DateTime.tryParse(contact['lastActive']?.toString() ?? '') ?? DateTime.now()).toLocal();
    final bool isWithin24h = DateTime.now().difference(lastActive).inHours < 24;

    return Column(
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
                        style: TextStyle(fontSize: 16, color: const Color.fromARGB(255, 99, 99, 99)),
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

  // Converts any DateTime to IST (UTC+5:30) and returns HH:mm
  String _formatDate(DateTime date) {
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    return "${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}";
  }

  // Resolves message time from msg['time'] (ISO string) or msg['timestamp'] (Firestore)
  String _formatMessageTime(Map<String, dynamic> msg) {
    if (msg['time'] != null) {
      final parsed = DateTime.tryParse(msg['time'].toString());
      if (parsed != null) return _formatDate(parsed);
    }
    if (msg['timestamp'] != null) {
      return _formatDate((msg['timestamp'] as dynamic).toDate());
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.primaryColor : Colors.white,
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
                  child: _buildContent(isMe, messageType),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime(msg),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isMe, String? messageType) {
    final textColor = isMe ? Colors.white : AppTheme.secondaryColor;
    final mutedColor = isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500;

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
                Text('Template', style: TextStyle(fontSize: 11, color: mutedColor)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              templateBody ?? (templateName != null ? '📋 Template: $templateName' : '📋 Template'),
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
        return _iconLabel(Icons.image_outlined, '📷 Image', textColor, mutedColor);

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
        return _iconLabel(Icons.play_circle_outline, '🎥 Video', textColor, mutedColor);

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
        return _iconLabel(Icons.graphic_eq, '🎵 Audio message', textColor, mutedColor);

      case 'document':
        final docText = msg['text'] as String?;
        return _iconLabel(
          Icons.insert_drive_file_outlined,
          docText != null && docText.isNotEmpty ? '📄 $docText' : '📄 Document',
          textColor,
          mutedColor,
        );

      case 'sticker':
        return Text('😊 Sticker', style: TextStyle(color: textColor, fontSize: 24));

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
        final title = payload?['title'] as String? ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 14, color: mutedColor),
                const SizedBox(width: 4),
                Text('Reply', style: TextStyle(fontSize: 11, color: mutedColor)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: textColor)),
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
                Text('Button Reply', style: TextStyle(fontSize: 11, color: mutedColor)),
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

  Widget _iconLabel(IconData icon, String label, Color textColor, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor)),
      ],
    );
  }
}

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
    final iconColor = isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500;

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
        errorBuilder: (context, error, stackTrace) => _fallback(textColor, iconColor),
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
                  child: Text('Failed to load image',
                      style: TextStyle(color: Colors.white)),
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
    _videoUrl = '${widget.baseUrl}/media/${widget.mediaId}?token=${widget.authToken}';
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
                child: Icon(Icons.play_arrow_rounded, color: iconColor, size: 32),
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
