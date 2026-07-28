import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/notification_bloc.dart';
import '../pages/notifications_page.dart';

class NotificationBellIcon extends StatelessWidget {
  final String tenantId;
  final VoidCallback? onTap;

  const NotificationBellIcon({
    super.key,
    required this.tenantId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final count = state.unreadCount;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF2E7D32), // Sendzyy theme green
                size: 26,
              ),
              tooltip: 'Notifications ($count unread)',
              onPressed: onTap ??
                  () {
                    context.read<NotificationBloc>().add(
                          LoadNotificationsEvent(tenantId: tenantId),
                        );
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          width: 500,
                          height: 650,
                          child: NotificationsPage(tenantId: tenantId),
                        ),
                      ),
                    );
                  },
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30), // Red badge color
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _formatBadgeCount(count),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatBadgeCount(int count) {
    if (count > 9999) return '9.9k+';
    if (count > 999) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
