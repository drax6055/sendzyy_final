class NotificationModel {
  final String id;
  final String tenantId;
  final String title;
  final String body;
  final String? icon;
  final String? imageUrl;
  final String type;
  final String category;
  final Map<String, dynamic> actionData;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.body,
    this.icon,
    this.imageUrl,
    required this.type,
    required this.category,
    required this.actionData,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      icon: json['icon'],
      imageUrl: json['imageUrl'],
      type: json['type'] ?? 'system',
      category: json['category'] ?? 'system',
      actionData: json['actionData'] is Map
          ? Map<String, dynamic>.from(json['actionData'])
          : {},
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'title': title,
      'body': body,
      'icon': icon,
      'imageUrl': imageUrl,
      'type': type,
      'category': category,
      'actionData': actionData,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id,
      tenantId: tenantId,
      title: title,
      body: body,
      icon: icon,
      imageUrl: imageUrl,
      type: type,
      category: category,
      actionData: actionData,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
