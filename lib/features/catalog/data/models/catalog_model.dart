class CatalogModel {
  final String catalogId;
  final String catalogName;
  final String verticalType;
  final bool isLinked;
  final int productCount;
  final String? dbId;

  const CatalogModel({
    required this.catalogId,
    required this.catalogName,
    this.verticalType = 'commerce',
    this.isLinked = false,
    this.productCount = 0,
    this.dbId,
  });

  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    return CatalogModel(
      catalogId: json['catalogId']?.toString() ?? '',
      catalogName: json['catalogName']?.toString() ?? '',
      verticalType: json['verticalType']?.toString() ?? 'commerce',
      isLinked: json['isLinked'] == true,
      productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      dbId: json['_dbId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'catalogId': catalogId,
        'catalogName': catalogName,
        'verticalType': verticalType,
        'isLinked': isLinked,
        'productCount': productCount,
      };

  CatalogModel copyWith({
    String? catalogId,
    String? catalogName,
    String? verticalType,
    bool? isLinked,
    int? productCount,
    String? dbId,
  }) {
    return CatalogModel(
      catalogId: catalogId ?? this.catalogId,
      catalogName: catalogName ?? this.catalogName,
      verticalType: verticalType ?? this.verticalType,
      isLinked: isLinked ?? this.isLinked,
      productCount: productCount ?? this.productCount,
      dbId: dbId ?? this.dbId,
    );
  }
}
