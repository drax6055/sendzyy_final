class ChatbotModel {
  final String id;
  final String name;
  final List<String> triggerKeywords;
  final Map<String, dynamic> flow;
  final bool isActive;
  final DateTime updatedAt;

  ChatbotModel({
    required this.id,
    required this.name,
    required this.triggerKeywords,
    required this.flow,
    required this.isActive,
    required this.updatedAt,
  });

  factory ChatbotModel.fromJson(Map<String, dynamic> json) {
    return ChatbotModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      triggerKeywords: List<String>.from(json['triggerKeywords'] ?? []),
      flow: Map<String, dynamic>.from(json['flow'] ?? {}),
      isActive: json['isActive'] ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'triggerKeywords': triggerKeywords,
      'flow': flow,
      'isActive': isActive,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class DailyAnalytics {
  final DateTime date;
  final int totalSessions;
  final int completedSessions;
  final int droppedSessions;
  final int messagesSent;

  DailyAnalytics({
    required this.date,
    required this.totalSessions,
    required this.completedSessions,
    required this.droppedSessions,
    required this.messagesSent,
  });

  factory DailyAnalytics.fromJson(Map<String, dynamic> json) {
    return DailyAnalytics(
      date: DateTime.parse(json['date']),
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      droppedSessions: json['droppedSessions'] ?? 0,
      messagesSent: json['messagesSent'] ?? 0,
    );
  }
}

