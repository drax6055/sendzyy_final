class ClientTriggerModel {
  final String id;
  final String tenantId;
  final String templateName;
  final String templateLanguage;
  final String mediaId;
  final String mediaType;
  final Map<String, String> variableMapping;
  final bool isActive;
  final DateTime? createdAt;

  ClientTriggerModel({
    required this.id,
    required this.tenantId,
    required this.templateName,
    required this.templateLanguage,
    this.mediaId = '',
    this.mediaType = '',
    this.variableMapping = const {},
    required this.isActive,
    this.createdAt,
  });

  factory ClientTriggerModel.fromJson(Map<String, dynamic> json) {
    return ClientTriggerModel(
      id: json['_id'] ?? json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      templateName: json['templateName'] ?? '',
      templateLanguage: json['templateLanguage'] ?? 'en_US',
      mediaId: json['mediaId'] ?? '',
      mediaType: json['mediaType'] ?? '',
      variableMapping: (json['variableMapping'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v?.toString() ?? '')),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  ClientTriggerModel copyWith({
    String? id,
    String? tenantId,
    String? templateName,
    String? templateLanguage,
    String? mediaId,
    String? mediaType,
    Map<String, String>? variableMapping,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ClientTriggerModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      templateName: templateName ?? this.templateName,
      templateLanguage: templateLanguage ?? this.templateLanguage,
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      variableMapping: variableMapping ?? this.variableMapping,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
