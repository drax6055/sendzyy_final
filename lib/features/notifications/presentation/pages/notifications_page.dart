import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFF1B5E20)),
            SizedBox(width: 8),
            Text(
              'Notification Center',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2E7D32)),
            label: const Text(
              'Mark All Read',
              style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              context.read<NotificationBloc>().add(
                    MarkAllNotificationsReadEvent(tenantId: widget.tenantId),
                  );
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
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
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
              icon: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
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
