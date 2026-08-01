class ClientModel {
  final String id;
  final String tenantId;
  final String name;
  final String mobileNumber;
  final String? companyName;
  final String? emailId;
  final String? venue;
  final String? remark;
  final DateTime createdAt;

  ClientModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.mobileNumber,
    this.companyName,
    this.emailId,
    this.venue,
    this.remark,
    required this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['_id'] ?? json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      name: json['name'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      companyName: json['companyName'],
      emailId: json['emailId'],
      venue: json['venue'] as String?,
      remark: json['remark'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobileNumber': mobileNumber,
      'companyName': companyName,
      'emailId': emailId,
      if (venue != null) 'venue': venue,
      if (remark != null) 'remark': remark,
    };
  }
}

