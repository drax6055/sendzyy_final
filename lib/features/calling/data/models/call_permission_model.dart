import 'package:equatable/equatable.dart';

enum PermissionStatusState { noPermission, temporary, permanent }

class PermissionLimit extends Equatable {
  final String timePeriod;       // e.g. "PT24H", "P7D"
  final int maxAllowed;
  final int currentUsage;
  final DateTime? limitExpirationTime;

  const PermissionLimit({
    required this.timePeriod,
    required this.maxAllowed,
    required this.currentUsage,
    this.limitExpirationTime,
  });

  factory PermissionLimit.fromJson(Map<String, dynamic> json) {
    return PermissionLimit(
      timePeriod: json['time_period'] as String? ?? '',
      maxAllowed: json['max_allowed'] as int? ?? 0,
      currentUsage: json['current_usage'] as int? ?? 0,
      limitExpirationTime: json['limit_expiration_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['limit_expiration_time'] as int) * 1000,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time_period': timePeriod,
      'max_allowed': maxAllowed,
      'current_usage': currentUsage,
      'limit_expiration_time': limitExpirationTime != null
          ? (limitExpirationTime!.millisecondsSinceEpoch ~/ 1000)
          : null,
    };
  }

  @override
  List<Object?> get props => [timePeriod, maxAllowed, currentUsage, limitExpirationTime];
}

class PermissionAction extends Equatable {
  final String actionName;        // e.g. "send_call_permission_request", "start_call"
  final bool canPerformAction;
  final List<PermissionLimit> limits;

  const PermissionAction({
    required this.actionName,
    required this.canPerformAction,
    required this.limits,
  });

  factory PermissionAction.fromJson(Map<String, dynamic> json) {
    final list = (json['limits'] as List<dynamic>?)
            ?.map((e) => PermissionLimit.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PermissionAction(
      actionName: json['action_name'] as String? ?? '',
      canPerformAction: json['can_perform_action'] as bool? ?? false,
      limits: list,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_name': actionName,
      'can_perform_action': canPerformAction,
      'limits': limits.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [actionName, canPerformAction, limits];
}

class CallPermissionModel extends Equatable {
  final PermissionStatusState status;
  final DateTime? expirationTime;
  final List<PermissionAction> actions;

  const CallPermissionModel({
    required this.status,
    this.expirationTime,
    this.actions = const [],
  });

  factory CallPermissionModel.fromJson(Map<String, dynamic> json) {
    final permObj = json['permission'] as Map<String, dynamic>? ?? {};
    final statusStr = permObj['status'] as String? ?? 'no_permission';
    PermissionStatusState state;
    switch (statusStr.toLowerCase()) {
      case 'temporary':
        state = PermissionStatusState.temporary;
        break;
      case 'permanent':
        state = PermissionStatusState.permanent;
        break;
      default:
        state = PermissionStatusState.noPermission;
    }

    final expInt = permObj['expiration_time'] ?? permObj['expiration'];
    final expTime = expInt != null
        ? DateTime.fromMillisecondsSinceEpoch((expInt as int) * 1000)
        : null;

    final actionList = (json['actions'] as List<dynamic>?)
            ?.map((e) => PermissionAction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CallPermissionModel(
      status: state,
      expirationTime: expTime,
      actions: actionList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission': {
        'status': status == PermissionStatusState.permanent
            ? 'permanent'
            : status == PermissionStatusState.temporary
                ? 'temporary'
                : 'no_permission',
        if (expirationTime != null)
          'expiration_time': (expirationTime!.millisecondsSinceEpoch ~/ 1000),
      },
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }

  bool get canStartCall {
    final action = actions.firstWhere(
      (a) => a.actionName == 'start_call',
      orElse: () => const PermissionAction(
        actionName: 'start_call',
        canPerformAction: false,
        limits: [],
      ),
    );
    return action.canPerformAction || status == PermissionStatusState.permanent || status == PermissionStatusState.temporary;
  }

  bool get canSendPermissionRequest {
    final action = actions.firstWhere(
      (a) => a.actionName == 'send_call_permission_request',
      orElse: () => const PermissionAction(
        actionName: 'send_call_permission_request',
        canPerformAction: true,
        limits: [],
      ),
    );
    return action.canPerformAction;
  }

  @override
  List<Object?> get props => [status, expirationTime, actions];
}
