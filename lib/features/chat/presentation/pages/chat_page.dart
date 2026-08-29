import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
// import 'package:iFloraBuzz/features/calling/presentation/bloc/call_control_bloc.dart';
// import 'package:iFloraBuzz/features/calling/presentation/pages/active_call_page.dart';

import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_product_picker_sheet.dart';

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
  String? _lastScrolledContactId;
  int _lastMessageCount = 0;

  /// 'all' or 'unread'
  String _selectedFilter = 'all';

  /// Mapping of contactId -> ISO8601 string of when it was last read
  final Map<String, String> _readContactTimestamps = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadReadContactTimestamps();
  }

  Future<void> _loadReadContactTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final tenantId = prefs.getString('tenant_id') ?? 'default';
      final String? jsonStr = prefs.getString(
        'read_contacts_timestamps_$tenantId',
      );
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          decoded.forEach((key, value) {
            _readContactTimestamps[key] = value.toString();
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading read contact timestamps: $e');
    }
  }

  Future<void> _saveReadContactTimestamps() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final tenantId = _prefs!.getString('tenant_id') ?? 'default';
      await _prefs!.setString(
        'read_contacts_timestamps_$tenantId',
        jsonEncode(_readContactTimestamps),
      );
    } catch (e) {
      debugPrint('Error saving read contact timestamps: $e');
    }
  }

  /// Jump instantly to bottom (used when switching contacts or initial load).
  void _jumpToBottom() {
    Future.microtask(() {
      if (_messagesScrollController.hasClients) {
        _messagesScrollController.jumpTo(0.0);
      }
    });
  }

  /// Smooth scroll to bottom (used when new messages arrive in same conversation).
  void _scrollToBottom() {
    if (_messagesScrollController.hasClients) {
      _messagesScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  /// Mark a conversation as read (called when tapped or loaded active).
  void _markAsRead(String contactId) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (_readContactTimestamps[contactId] != nowIso) {
      setState(() {
        _readContactTimestamps[contactId] = nowIso;
      });
      _saveReadContactTimestamps();
    }
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
          final contactId = state.selectedContactId;
          final msgCount = state.messages.length;

          if (contactId != _lastScrolledContactId) {
            _lastScrolledContactId = contactId;
            _lastMessageCount = msgCount;
            _jumpToBottom();
          } else if (msgCount > _lastMessageCount) {
            _lastMessageCount = msgCount;
            if (_messagesScrollController.hasClients) {
              final currentOffset = _messagesScrollController.offset;
              if (currentOffset < 200.0) {
                _scrollToBottom();
              }
            }
          }
          if (contactId != null) {
            _markAsRead(contactId);
          }
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
          final isMobile = ResponsiveHelper.isMobile(context);
          if (isMobile) {
            if (state.selectedContactId == null) {
              return _buildConversationSidebar(state);
            } else {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  context.read<ChatBloc>().add(SelectConversation(null));
                },
                child: _buildChatWindow(state),
              );
            }
          }
          return Row(
            children: [
              // 1. Conversation Sidebar
              SizedBox(width: 320, child: _buildConversationSidebar(state)),

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
    // Step 1: apply search filter
    final searchFiltered = _searchQuery.isEmpty
        ? state.conversations
        : state.conversations.where((c) {
            final name = (c['name'] as String? ?? '').toLowerCase();
            final number = (c['id'] as String? ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || number.contains(q);
          }).toList();

    // Step 2: apply All / Unread chip filter
    final filtered = _selectedFilter == 'unread'
        ? searchFiltered.where((c) {
            final contactId = c['id'] as String? ?? '';

            // Check if client replied to our template or message
            final hasReply = c['hasReply'] == true;
            if (!hasReply) {
              return false;
            }

            // Get last active time of the conversation
            final lastActive = c['lastActive'] is DateTime
                ? (c['lastActive'] as DateTime).toLocal()
                : (DateTime.tryParse(c['lastActive']?.toString() ?? '') ??
                          DateTime.now())
                      .toLocal();

            // Check if it was read after the last activity
            final lastReadStr = _readContactTimestamps[contactId];
            if (lastReadStr != null) {
              final lastRead = DateTime.tryParse(lastReadStr)?.toLocal();
              if (lastRead != null && !lastRead.isBefore(lastActive)) {
                return false;
              }
            }

            // 24h window must still be open
            return DateTime.now().difference(lastActive).inHours < 24;
          }).toList()
        : searchFiltered;

    // Count for badge on Unread chip
    final unreadCount = state.conversations.where((c) {
      final contactId = c['id'] as String? ?? '';

      // Check if client replied to our template or message
      final hasReply = c['hasReply'] == true;
      if (!hasReply) {
        return false;
      }

      // Get last active time of the conversation
      final lastActive = c['lastActive'] is DateTime
          ? (c['lastActive'] as DateTime).toLocal()
          : (DateTime.tryParse(c['lastActive']?.toString() ?? '') ??
                    DateTime.now())
                .toLocal();

      // Check if it was read after the last activity
      final lastReadStr = _readContactTimestamps[contactId];
      if (lastReadStr != null) {
        final lastRead = DateTime.tryParse(lastReadStr)?.toLocal();
        if (lastRead != null && !lastRead.isBefore(lastActive)) {
          return false;
        }
      }

      return DateTime.now().difference(lastActive).inHours < 24;
    }).length;

    final isMobileSidebar = ResponsiveHelper.isMobile(context);
    return Container(
      width: isMobileSidebar ? double.infinity : 350,
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
          // ── All / Unread Chip Filters ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'all',
                  badgeCount: null,
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Unread',
                  isSelected: _selectedFilter == 'unread',
                  badgeCount: unreadCount,
                  onTap: () => setState(() => _selectedFilter = 'unread'),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'unread'
                              ? Icons.mark_chat_read_outlined
                              : Icons.search_off,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFilter == 'unread'
                              ? 'All caught up!'
                              : 'No conversations found',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            _markAsRead(conv['id'] as String);
                            context.read<ChatBloc>().add(
                              SelectConversation(conv['id']),
                            );
                          },
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryColor.withValues(
                            alpha: 0.05,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.secondaryColor,
                            child: Text(
                              (conv['name'] as String?)?.isNotEmpty == true
                                  ? conv['name'][0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  conv['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required int? badgeCount,
    required VoidCallback onTap,
  }) {
    final color = AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ],
        ),
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
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 8 : 24,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                if (ResponsiveHelper.isMobile(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      context.read<ChatBloc>().add(SelectConversation(null));
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor,
                  child: Text(
                    (contact['name'] as String?)?.isNotEmpty == true
                        ? contact['name'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact['name'] ?? 'Unknown',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            contact['id'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 99, 99, 99),
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
                          Flexible(
                            child: Text(
                              isWithin24h
                                  ? '24h Window Open'
                                  : '24h Window Expired (Requires Template)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isWithin24h) ...[
                  const SizedBox(width: 4),
                  _WindowTimerWidget(lastActive: lastActive),
                ],
                // TODO: Work on this module later
                // const SizedBox(width: 8),
                // IconButton(
                //   icon: const Icon(Icons.call_rounded, color: Color(0xFF128C7E)),
                //   tooltip: 'Start Voice Call',
                //   onPressed: () {
                //     final toPhone = contact['id']?.toString() ?? '';
                //     final callerName = contact['name']?.toString() ?? 'Contact';
                //     if (toPhone.isEmpty) return;
                //
                //     context.read<CallControlBloc>().add(
                //           InitiateCallEvent(
                //             phoneNumberId: '',
                //             to: toPhone,
                //             callerName: callerName,
                //           ),
                //         );
                //
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(builder: (_) => const ActiveCallPage()),
                //     );
                //   },
                // ),

              ],
            ),
          ),

          // Messages Areas
          // Messages Areas
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: EdgeInsets.all(
                ResponsiveHelper.isMobile(context) ? 12 : 24,
              ),
              child: Builder(
                builder: (context) {
                  final reversedMessages = state.messages.reversed.toList();
                  return ListView.builder(
                    controller: _messagesScrollController,
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: reversedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = reversedMessages[index];
                      return _buildMessageBubble(msg, state.messages);
                    },
                  );
                },
              ),
            ),
          ),

          // Input Area
          _buildInputArea(state.selectedContactId!, isWithin24h, state.replyingToMessage),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, List<Map<String, dynamic>> allMessages) {
    final bloc = context.read<ChatBloc>();
    final isMobile = ResponsiveHelper.isMobile(context);
    final msgKey = msg['id'] ?? msg['wamid'] ?? msg['_id'] ?? msg['timestamp'] ?? msg.hashCode;
    return MessageRenderer(
      key: ValueKey(msgKey),
      msg: msg,
      allMessages: allMessages,
      maxWidth: MediaQuery.of(context).size.width * (isMobile ? 0.75 : 0.4),
      formatTime: _formatMessageTime,
      baseUrl: AppConstants.baseUrl,
      authToken: bloc.authToken,
      onReplyTap: () {
        context.read<ChatBloc>().add(SetReplyMessage(msg));
      },
    );
  }

  Widget _buildInputArea(
    String contactId,
    bool isWithin24h,
    Map<String, dynamic>? replyingToMessage,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToMessage != null) ...[
            _buildReplyingToBanner(replyingToMessage),
            const SizedBox(height: 10),
          ],
          isWithin24h
              ? Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                      onPressed: () => _showAttachmentMenu(context, contactId, replyingToMessage),
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
                        onSubmitted: (_) => _handleSend(contactId, replyingToMessage),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filled(
                      onPressed: () => _handleSend(contactId, replyingToMessage),
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
        ],
      ),
    );
  }

  Widget _buildReplyingToBanner(Map<String, dynamic> replyingMsg) {
    final String senderName = replyingMsg['isMe'] == true ? 'You' : 'Contact';
    final String? type = replyingMsg['messageType'] as String?;
    final String text = replyingMsg['text']?.toString() ?? '';
    String snippet = 'Original message';
    if (text.isNotEmpty) {
      snippet = text;
    } else if (type == 'image') {
      snippet = '📷 Photo';
    } else if (type == 'video') {
      snippet = '🎥 Video';
    } else if (type == 'audio' || type == 'voice') {
      snippet = '🎵 Audio';
    } else if (type == 'document') {
      snippet = '📄 Document';
    } else if (type == 'template') {
      snippet = '📋 Template';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $senderName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              context.read<ChatBloc>().add(SetReplyMessage(null));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  void _handleSend(String contactId, Map<String, dynamic>? replyingToMessage) {
    if (_messageController.text.trim().isNotEmpty) {
      final replyId = replyingToMessage?['id']?.toString();
      final replyWamid = replyingToMessage?['wamid']?.toString();
      context.read<ChatBloc>().add(
        SendMessage(
          contactId,
          _messageController.text.trim(),
          replyToMessageId: replyId,
          replyToWamid: replyWamid,
        ),
      );
      _messageController.clear();
    }
  }

  void _showAttachmentMenu(
    BuildContext context,
    String contactId,
    Map<String, dynamic>? replyingToMessage,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
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
                // Row 1: Camera options (mobile only) + Gallery/File options
                if (!kIsWeb) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _attachmentOption(
                        icon: Icons.camera_alt,
                        color: Colors.teal,
                        label: 'Camera\nPhoto',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _captureFromCamera(
                            contactId: contactId,
                            replyingToMessage: replyingToMessage,
                            isVideo: false,
                          );
                        },
                      ),
                      _attachmentOption(
                        icon: Icons.videocam_rounded,
                        color: Colors.deepOrange,
                        label: 'Camera\nVideo',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _captureFromCamera(
                            contactId: contactId,
                            replyingToMessage: replyingToMessage,
                            isVideo: true,
                          );
                        },
                      ),
                      _attachmentOption(
                        icon: Icons.image,
                        color: Colors.purple,
                        label: 'Gallery\n(Max 5MB)',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAndSendAttachment(
                            contactId: contactId,
                            type: 'image',
                            extensions: ['jpg', 'jpeg', 'png'],
                            maxSize: 5 * 1024 * 1024,
                            replyingToMessage: replyingToMessage,
                          );
                        },
                      ),
                      _attachmentOption(
                        icon: Icons.videocam,
                        color: Colors.pink,
                        label: 'Video\n(Max 16MB)',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAndSendAttachment(
                            contactId: contactId,
                            type: 'video',
                            extensions: ['mp4', '3gp'],
                            maxSize: 16 * 1024 * 1024,
                            replyingToMessage: replyingToMessage,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Web: show original row without camera
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _attachmentOption(
                        icon: Icons.image,
                        color: Colors.purple,
                        label: 'Image\n(Max 5MB)',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAndSendAttachment(
                            contactId: contactId,
                            type: 'image',
                            extensions: ['jpg', 'jpeg', 'png'],
                            maxSize: 5 * 1024 * 1024,
                            replyingToMessage: replyingToMessage,
                          );
                        },
                      ),
                      _attachmentOption(
                        icon: Icons.videocam,
                        color: Colors.pink,
                        label: 'Video\n(Max 16MB)',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickAndSendAttachment(
                            contactId: contactId,
                            type: 'video',
                            extensions: ['mp4', '3gp'],
                            maxSize: 16 * 1024 * 1024,
                            replyingToMessage: replyingToMessage,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Row 2: Audio, Document, Catalog (always shown)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attachmentOption(
                      icon: Icons.audiotrack,
                      color: Colors.orange,
                      label: 'Audio\n(Max 16MB)',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'audio',
                          extensions: ['aac', 'mp3', 'amr', 'ogg'],
                          maxSize: 16 * 1024 * 1024,
                          replyingToMessage: replyingToMessage,
                        );
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.insert_drive_file,
                      color: Colors.blue,
                      label: 'Document\n(Max 100MB)',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _pickAndSendAttachment(
                          contactId: contactId,
                          type: 'document',
                          extensions: [], // Allow all extensions
                          maxSize: 100 * 1024 * 1024,
                          replyingToMessage: replyingToMessage,
                        );
                      },
                    ),
                    _attachmentOption(
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Catalog\nMessage',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => CatalogProductPickerSheet(
                            contactId: contactId,
                          ),
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

  /// Captures a photo or video from the device camera.
  /// Shows a preview dialog before sending.
  Future<void> _captureFromCamera({
    required String contactId,
    Map<String, dynamic>? replyingToMessage,
    required bool isVideo,
  }) async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      if (isVideo) {
        picked = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (picked == null || !mounted) return;

    // Show preview dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CameraPreviewDialog(
        file: picked!,
        isVideo: isVideo,
      ),
    );

    if (confirmed != true || !mounted) return;

    // Convert to PlatformFile and send
    final bytes = await picked.readAsBytes();
    final platformFile = PlatformFile(
      name: picked.name,
      size: bytes.length,
      bytes: bytes,
      path: picked.path,
    );
    _sendFileAttachment(
      contactId: contactId,
      file: platformFile,
      type: isVideo ? 'video' : 'image',
      replyingToMessage: replyingToMessage,
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
              backgroundColor: color.withValues(alpha: 0.1),
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
    Map<String, dynamic>? replyingToMessage,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
        withData: kIsWeb,
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

      final chatBloc = context.read<ChatBloc>();
      bool isDialogShowing = false;
      if (mounted) {
        isDialogShowing = true;
        _showSendingOverlay(context, file.name);
      }

      final mediaId = await chatBloc.uploadMedia(file);

      if (isDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mediaId.isNotEmpty) {
        final replyId = replyingToMessage?['id']?.toString();
        final replyWamid = replyingToMessage?['wamid']?.toString();
        chatBloc.add(
          SendMediaMessage(
            contactId: contactId,
            mediaId: mediaId,
            type: type,
            filename: type == 'document' ? file.name : null,
            replyToMessageId: replyId,
            replyToWamid: replyWamid,
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

  /// Sends an already-resolved PlatformFile as a media message.
  /// Used by camera capture after preview confirmation.
  Future<void> _sendFileAttachment({
    required String contactId,
    required PlatformFile file,
    required String type,
    Map<String, dynamic>? replyingToMessage,
  }) async {
    final chatBloc = context.read<ChatBloc>();
    bool isDialogShowing = false;
    if (mounted) {
      isDialogShowing = true;
      _showSendingOverlay(context, file.name);
    }
    try {
      final mediaId = await chatBloc.uploadMedia(file);
      if (isDialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
      if (mediaId.isNotEmpty) {
        final replyId = replyingToMessage?['id']?.toString();
        final replyWamid = replyingToMessage?['wamid']?.toString();
        chatBloc.add(SendMediaMessage(
          contactId: contactId,
          mediaId: mediaId,
          type: type,
          filename: type == 'document' ? file.name : null,
          replyToMessageId: replyId,
          replyToWamid: replyWamid,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${type[0].toUpperCase()}${type.substring(1)} sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to upload media to server.');
      }
    } catch (e) {
      if (isDialogShowing && mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
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
  final List<Map<String, dynamic>>? allMessages;
  final double maxWidth;
  final String Function(Map<String, dynamic>) formatTime;
  final String? baseUrl;
  final String? authToken;
  final VoidCallback? onReplyTap;

  const MessageRenderer({
    super.key,
    required this.msg,
    this.allMessages,
    required this.maxWidth,
    required this.formatTime,
    this.baseUrl,
    this.authToken,
    this.onReplyTap,
  });

  Widget _buildQuotedReply(BuildContext context, bool isMe) {
    final contextMessageId = msg['contextMessageId'] as String?;
    final fallbackPreview = msg['replyContextPreview'] as String?;

    if ((contextMessageId == null || contextMessageId.isEmpty) &&
        (fallbackPreview == null || fallbackPreview.isEmpty)) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic>? parentMsg;
    if (allMessages != null && contextMessageId != null && contextMessageId.isNotEmpty) {
      for (final m in allMessages!) {
        if (m['wamid'] == contextMessageId || m['id'] == contextMessageId) {
          parentMsg = m;
          break;
        }
      }
    }

    final String parentSender = parentMsg == null
        ? (isMe ? 'Contact' : 'You')
        : (parentMsg['isMe'] == true ? 'You' : 'Contact');

    String snippet = (fallbackPreview != null && fallbackPreview.isNotEmpty)
        ? fallbackPreview
        : 'Original message';

    if (parentMsg != null) {
      final String? type = parentMsg['messageType'] as String?;
      final String text = parentMsg['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        snippet = text;
      } else if (parentMsg['templateBody'] != null &&
          parentMsg['templateBody'].toString().isNotEmpty) {
        snippet = parentMsg['templateBody'].toString();
      } else if (parentMsg['templateName'] != null &&
          parentMsg['templateName'].toString().isNotEmpty) {
        snippet = '📋 ${parentMsg['templateName']}';
      } else if (type == 'image') {
        snippet = '📷 Photo';
      } else if (type == 'video') {
        snippet = '🎥 Video';
      } else if (type == 'audio' || type == 'voice') {
        snippet = '🎵 Audio';
      } else if (type == 'document') {
        snippet = '📄 Document';
      } else if (type == 'template') {
        snippet = '📋 Template';
      } else if (type == 'location') {
        snippet = '📍 Location';
      } else if (type == 'contacts') {
        snippet = '👤 Contact';
      }
    }

    final Color bgColor = isMe
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.grey.shade100;
    final Color barColor = isMe ? Colors.white : AppTheme.primaryColor;
    final Color textColor = isMe ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: barColor, width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parentSender,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: barColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

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
          _buildQuotedReply(context, isMe),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildContent(
              context,
              isMe,
              messageType,
              isBotSent: isBotSent,
            ),
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

    Widget hoverBubble = _HoverableMessageBubble(
      isMe: isMe,
      onReply: onReplyTap,
      child: bubble,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
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
              hoverBubble,
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

  Widget _buildContent(
    BuildContext context,
    bool isMe,
    String? messageType, {
    bool isBotSent = false,
  }) {
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
        final docMediaUrl = msg['mediaUrl'] as String?;
        final docText = msg['text'] as String?;
        final docFilename = docText != null && docText.isNotEmpty
            ? docText
            : 'document';
        if (docMediaUrl != null && baseUrl != null && authToken != null) {
          return _DocumentBubble(
            mediaId: docMediaUrl,
            filename: docFilename,
            isMe: isMe,
            baseUrl: baseUrl!,
            authToken: authToken!,
          );
        }
        return _iconLabel(
          Icons.insert_drive_file_outlined,
          '📄 $docFilename',
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
        final replyLabel = interactiveType == 'list_reply'
            ? 'List Reply'
            : 'Button Reply';
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
            color: isMe
                ? Colors.teal.shade800.withValues(alpha: 0.3)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? Colors.teal.shade700.withValues(alpha: 0.5)
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.15,
                    ),
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
                            style: TextStyle(color: mutedColor, fontSize: 11),
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
                          content: Text(
                            'Copied contact number "$phone" to clipboard.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                              color: isMe
                                  ? Colors.white
                                  : AppTheme.primaryColor,
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
    final buttons = (payload['buttons'] as List<dynamic>? ?? [])
        .map((b) {
          return (b as Map<String, dynamic>)['label'] as String? ?? '';
        })
        .where((l) => l.isNotEmpty)
        .toList();

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
    final items = (payload['items'] as List<dynamic>? ?? [])
        .map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'title': m['title'] as String? ?? '',
            'description': m['description'] as String? ?? '',
          };
        })
        .where((i) => (i['title'] as String).isNotEmpty)
        .toList();

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
      builder: (dialogCtx) => Dialog(
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
            // Top bar: close + download
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white, size: 28),
                    tooltip: 'Download',
                    onPressed: () => _downloadMediaFile(
                      context: dialogCtx,
                      url: url,
                      filename: 'image_${mediaId.replaceAll('/', '_')}.jpg',
                      mimeType: 'image/jpeg',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Downloads a media file.
  /// On Web: triggers browser download via webDownloadBytes.
  /// On Mobile: saves to temp dir and opens with native app.
  Future<void> _downloadMediaFile({
    required BuildContext context,
    required String url,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $authToken'},
        ),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data received');

      if (kIsWeb) {
        await webDownloadBytes(bytes, filename, mimeType: mimeType);
      } else {
        Directory dir;
        if (Platform.isAndroid) {
          dir = (await getExternalStorageDirectory()) ??
              await getTemporaryDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
                ? 'Download started'
                : 'Saved: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'audio-player-${widget.mediaId}';
    _registerAudioElement();
  }

  void _registerAudioElement() {
    final audioUrl =
        '${widget.baseUrl}/media/${widget.mediaId}?token=${widget.authToken}';
    registerWebAudioElement(_viewId, audioUrl);
  }

  Future<void> _downloadAudio() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = '${widget.baseUrl}/media/${widget.mediaId}';
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer ${widget.authToken}'},
        ),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data');
      const filename = 'audio_message.ogg';
      if (kIsWeb) {
        await webDownloadBytes(bytes, filename, mimeType: 'audio/ogg');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio ready'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade100;
    final textColor = widget.isMe ? Colors.white : AppTheme.secondaryColor;

    if (kIsWeb) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 48,
            child: HtmlElementView(viewType: _viewId),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(Icons.download, size: 18, color: textColor),
                    tooltip: 'Download audio',
                    onPressed: _downloadAudio,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
        ],
      );
    }

    // Mobile: show card with download/open
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.audiotrack, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🎵 Audio Message',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(Icons.open_in_new, size: 20, color: textColor),
                  tooltip: 'Open audio',
                  onPressed: _downloadAudio,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
      ),
    );
  }
}

/// Shows a video thumbnail with a play button overlay.
/// On Web: opens in browser tab. On Mobile: downloads and opens with native player.
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
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _videoUrl =
        '${widget.baseUrl}/media/${widget.mediaId}?token=${widget.authToken}';
    _viewId = 'video-thumb-${widget.mediaId}';
    _registerVideoElement();
  }

  void _registerVideoElement() {
    registerWebVideoElement(_viewId, _videoUrl);
  }

  Future<void> _openOrDownloadVideo() async {
    if (kIsWeb) {
      webOpenUrl(_videoUrl);
      return;
    }
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = '${widget.baseUrl}/media/${widget.mediaId}';
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer ${widget.authToken}'},
        ),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/video_${widget.mediaId}.mp4');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open video: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Colors.white.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: _openOrDownloadVideo,
      child: SizedBox(
        width: 200,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HtmlElementView(viewType: _viewId),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black87,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
            Center(
              child: _isDownloading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Container(
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

/// Shows a document card with filename and a Download/Open button.
/// On Web: triggers browser download. On Mobile: saves to temp dir and opens with native app.
class _DocumentBubble extends StatefulWidget {
  final String mediaId;
  final String filename;
  final bool isMe;
  final String baseUrl;
  final String authToken;

  const _DocumentBubble({
    required this.mediaId,
    required this.filename,
    required this.isMe,
    required this.baseUrl,
    required this.authToken,
  });

  @override
  State<_DocumentBubble> createState() => _DocumentBubbleState();
}

class _DocumentBubbleState extends State<_DocumentBubble> {
  bool _isDownloading = false;

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _openDocument() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = '${widget.baseUrl}/media/${widget.mediaId}';
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer ${widget.authToken}'},
        ),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data');

      if (kIsWeb) {
        await webDownloadBytes(bytes, widget.filename,
            mimeType: 'application/octet-stream');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Download started'), backgroundColor: Colors.green),
          );
        }
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.filename}');
        await file.writeAsBytes(bytes);
        final result = await OpenFile.open(file.path);
        if (mounted && result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open document: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : AppTheme.secondaryColor;
    final subColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.grey.shade600;
    final cardColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade50;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(_iconForFile(widget.filename),
              color: AppTheme.primaryColor, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.filename,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Document',
                  style: TextStyle(color: subColor, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(
                    kIsWeb ? Icons.download : Icons.open_in_new,
                    size: 20,
                    color: textColor,
                  ),
                  tooltip: kIsWeb ? 'Download' : 'Open',
                  onPressed: _openDocument,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
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
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
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

class _HoverableMessageBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final bool isMe;

  const _HoverableMessageBubble({
    required this.child,
    this.onReply,
    required this.isMe,
  });

  @override
  State<_HoverableMessageBubble> createState() => _HoverableMessageBubbleState();
}

class _HoverableMessageBubbleState extends State<_HoverableMessageBubble> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final replyBtn = IconButton(
      icon: Icon(
        Icons.reply_rounded,
        size: 18,
        color: Colors.grey.shade600,
      ),
      tooltip: 'Reply',
      onPressed: widget.onReply,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isHovered && !widget.isMe && widget.onReply != null) replyBtn,
          Flexible(child: widget.child),
          if (_isHovered && widget.isMe && widget.onReply != null) replyBtn,
        ],
      ),
    );
  }
}

/// Preview dialog shown after camera capture, before the file is sent.
/// Returns true if the user taps Send, false/null if they cancel.
class _CameraPreviewDialog extends StatelessWidget {
  final XFile file;
  final bool isVideo;

  const _CameraPreviewDialog({
    required this.file,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isVideo ? 'Video Preview' : 'Photo Preview',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
            child: isVideo
                ? Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline,
                            color: Colors.white, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          file.name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Image.file(
                    File(file.path),
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: 300,
                      color: Colors.black54,
                      child: const Icon(Icons.broken_image,
                          color: Colors.white54, size: 64),
                    ),
                  ),
          ),
          // File name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              file.name,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
