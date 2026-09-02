import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';
import '../bloc/notification_bloc.dart';
import '../../data/models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  final String tenantId;

  const NotificationsPage({super.key, required this.tenantId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(
      LoadNotificationsEvent(
        tenantId: widget.tenantId,
        category: _selectedCategory,
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Color(0xFFD32F2F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Clear All Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _selectedCategory == 'all'
                    ? 'Are you sure you want to clear all notifications? This action cannot be undone.'
                    : 'Are you sure you want to clear all notifications in "${_selectedCategory.toUpperCase()}"? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      context.read<NotificationBloc>().add(
                        ClearAllNotificationsEvent(
                          tenantId: widget.tenantId,
                          category: _selectedCategory == 'all' ? null : _selectedCategory,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Color(0xFF1B5E20)),
        elevation: 1,
        titleSpacing: isMobile ? 4 : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Notification Center',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 15 : 18,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              final hasNotifications = state.notifications.isNotEmpty;
              final hasUnread = state.unreadCount > 0 || state.notifications.any((n) => !n.isRead);

              if (isMobile) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasUnread)
                      IconButton(
                        icon: const Icon(
                          Icons.done_all_rounded,
                          color: Color(0xFF2E7D32),
                        ),
                        tooltip: 'Mark All Read',
                        onPressed: () {
                          context.read<NotificationBloc>().add(
                            MarkAllNotificationsReadEvent(tenantId: widget.tenantId),
                          );
                        },
                      ),
                    if (hasNotifications)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Color(0xFFD32F2F),
                        ),
                        tooltip: 'Clear All',
                        onPressed: () => _showClearAllDialog(context),
                      ),
                  ],
                );
              } else {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasUnread)
                      TextButton.icon(
                        icon: const Icon(
                          Icons.done_all_rounded,
                          size: 18,
                          color: Color(0xFF2E7D32),
                        ),
                        label: const Text(
                          'Mark All Read',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          context.read<NotificationBloc>().add(
                            MarkAllNotificationsReadEvent(tenantId: widget.tenantId),
                          );
                        },
                      ),
                    if (hasNotifications) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          size: 18,
                          color: Color(0xFFD32F2F),
                        ),
                        label: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _showClearAllDialog(context),
                      ),
                    ],
                  ],
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'All'),
                  _buildCategoryChip('chat', '💬 Chat'),
                  _buildCategoryChip('campaign', '📣 Campaigns'),
                  _buildCategoryChip('payment', '💳 Payments'),
                  _buildCategoryChip('lead', '🛒 Leads'),
                  _buildCategoryChip('system', '⚙️ System'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Notification List View
          Expanded(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                if (state.isLoading && state.notifications.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  );
                }

                if (state.notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.notifications.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final item = state.notifications[index];
                    return _buildNotificationCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF333333),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        selectedColor: const Color(0xFF2E7D32),
        backgroundColor: Colors.grey.shade100,
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          setState(() => _selectedCategory = categoryKey);
          context.read<NotificationBloc>().add(
            LoadNotificationsEvent(
              tenantId: widget.tenantId,
              category: categoryKey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel item) {
    final isUnread = !item.isRead;

    return InkWell(
      onTap: () {
        if (isUnread) {
          context.read<NotificationBloc>().add(
            MarkSingleNotificationReadEvent(
              notificationId: item.id,
              tenantId: widget.tenantId,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF1FDF3) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread ? const Color(0xFFA5D6A7) : Colors.grey.shade200,
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread Indicator Dot
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Icon / Category Avatar
            _buildCategoryAvatar(item.category),
            const SizedBox(width: 12),

            // Title, Body, Timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF1B5E20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
              tooltip: 'Dismiss',
              onPressed: () {
                context.read<NotificationBloc>().add(
                  DeleteNotificationEvent(
                    notificationId: item.id,
                    tenantId: widget.tenantId,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAvatar(String category) {
    IconData iconData = Icons.notifications_rounded;
    Color iconColor = const Color(0xFF2E7D32);

    switch (category) {
      case 'chat':
        iconData = Icons.forum_rounded;
        iconColor = const Color(0xFF0288D1);
        break;
      case 'campaign':
        iconData = Icons.campaign_rounded;
        iconColor = const Color(0xFF7B1FA2);
        break;
      case 'payment':
        iconData = Icons.payments_rounded;
        iconColor = const Color(0xFF2E7D32);
        break;
      case 'lead':
        iconData = Icons.shopping_cart_rounded;
        iconColor = const Color(0xFFE65100);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 20, color: iconColor),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
