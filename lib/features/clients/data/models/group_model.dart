class GroupModel {
  final String id;
  final String tenantId;
  final String name;
  final List<String> clientIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.clientIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['_id'] ?? json['id'] ?? '',
        tenantId: json['tenantId'] ?? '',
        name: json['name'] ?? '',
        clientIds: List<String>.from(json['clientIds'] ?? []),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'clientIds': clientIds,
      };
}

