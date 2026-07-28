import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

// ── EVENTS ───────────────────────────────────────────────────────────────────
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class LoadNotificationsEvent extends NotificationEvent {
  final String tenantId;
  final int page;
  final String category;

  const LoadNotificationsEvent({
    required this.tenantId,
    this.page = 1,
    this.category = 'all',
  });

  @override
  List<Object?> get props => [tenantId, page, category];
}

class RefreshUnreadCountEvent extends NotificationEvent {
  final String tenantId;
  const RefreshUnreadCountEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

class MarkSingleNotificationReadEvent extends NotificationEvent {
  final String notificationId;
  final String tenantId;

  const MarkSingleNotificationReadEvent({
    required this.notificationId,
    required this.tenantId,
  });

  @override
  List<Object?> get props => [notificationId, tenantId];
}

class MarkAllNotificationsReadEvent extends NotificationEvent {
  final String tenantId;

  const MarkAllNotificationsReadEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

class NewNotificationReceivedSocketEvent extends NotificationEvent {
  final NotificationModel notification;
  final int unreadCount;

  const NewNotificationReceivedSocketEvent({
    required this.notification,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [notification, unreadCount];
}

class DeleteNotificationEvent extends NotificationEvent {
  final String notificationId;
  final String tenantId;

  const DeleteNotificationEvent({
    required this.notificationId,
    required this.tenantId,
  });

  @override
  List<Object?> get props => [notificationId, tenantId];
}

// ── STATES ───────────────────────────────────────────────────────────────────
class NotificationState extends Equatable {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCategory;
  final int page;
  final bool hasMorePages;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory = 'all',
    this.page = 1,
    this.hasMorePages = false,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    int? page,
    bool? hasMorePages,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      page: page ?? this.page,
      hasMorePages: hasMorePages ?? this.hasMorePages,
    );
  }

  @override
  List<Object?> get props => [
        notifications,
        unreadCount,
        isLoading,
        errorMessage,
        selectedCategory,
        page,
        hasMorePages,
      ];
}

// ── BLOC ─────────────────────────────────────────────────────────────────────
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository repository;

  NotificationBloc({required this.repository}) : super(const NotificationState()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<RefreshUnreadCountEvent>(_onRefreshUnreadCount);
    on<MarkSingleNotificationReadEvent>(_onMarkSingleRead);
    on<MarkAllNotificationsReadEvent>(_onMarkAllRead);
    on<NewNotificationReceivedSocketEvent>(_onNewNotificationSocket);
    on<DeleteNotificationEvent>(_onDeleteNotification);
  }

  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final res = await repository.fetchNotifications(
        tenantId: event.tenantId,
        page: event.page,
        category: event.category,
      );

      final List<NotificationModel> newItems = res['notifications'];
      final List<NotificationModel> combined = event.page == 1
          ? newItems
          : [...state.notifications, ...newItems];

      emit(state.copyWith(
        notifications: combined,
        unreadCount: res['unreadCount'],
        isLoading: false,
        selectedCategory: event.category,
        page: event.page,
        hasMorePages: event.page < (res['pages'] ?? 1),
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshUnreadCount(
    RefreshUnreadCountEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final count = await repository.getUnreadCount(tenantId: event.tenantId);
      emit(state.copyWith(unreadCount: count));
    } catch (_) {}
  }

  Future<void> _onMarkSingleRead(
    MarkSingleNotificationReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final updatedUnread = await repository.markRead(
        notificationId: event.notificationId,
        tenantId: event.tenantId,
      );

      final updatedList = state.notifications.map((n) {
        if (n.id == event.notificationId) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList();

      emit(state.copyWith(
        notifications: updatedList,
        unreadCount: updatedUnread,
      ));
    } catch (_) {}
  }

  Future<void> _onMarkAllRead(
    MarkAllNotificationsReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await repository.markAllRead(tenantId: event.tenantId);

      final updatedList = state.notifications
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList();

      emit(state.copyWith(
        notifications: updatedList,
        unreadCount: 0,
      ));
    } catch (_) {}
  }

  void _onNewNotificationSocket(
    NewNotificationReceivedSocketEvent event,
    Emitter<NotificationState> emit,
  ) {
    final updatedList = [event.notification, ...state.notifications];
    emit(state.copyWith(
      notifications: updatedList,
      unreadCount: event.unreadCount,
    ));
  }

  Future<void> _onDeleteNotification(
    DeleteNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final newCount = await repository.deleteNotification(
        notificationId: event.notificationId,
        tenantId: event.tenantId,
      );

      final updatedList =
          state.notifications.where((n) => n.id != event.notificationId).toList();

      emit(state.copyWith(
        notifications: updatedList,
        unreadCount: newCount,
      ));
    } catch (_) {}
  }
}
