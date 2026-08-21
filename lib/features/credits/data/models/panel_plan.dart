class PanelPlan {
  final String id;
  final String name;
  final String description;
  final int basePrice;
  final int gstPercent;
  final int totalPrice;
  final int panelDays;

  const PanelPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.gstPercent,
    required this.totalPrice,
    required this.panelDays,
  });

  String get durationLabel {
    if (panelDays <= 31) return '1 Month';
    if (panelDays <= 92) return '3 Months';
    if (panelDays <= 182) return '6 Months';
    return '12 Months';
  }

  factory PanelPlan.fromJson(Map<String, dynamic> json) => PanelPlan(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        basePrice: (json['basePrice'] as num?)?.toInt() ?? 12711,
        gstPercent: (json['gstPercent'] as num?)?.toInt() ?? 18,
        totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 14999,
        panelDays: (json['panelDays'] as num?)?.toInt() ?? 365,
      );
}
