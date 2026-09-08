class OrderProductItem {
  final String productRetailerId;
  final int quantity;
  final double itemPrice;
  final String currency;
  final String productName;
  final String imageUrl;

  const OrderProductItem({
    required this.productRetailerId,
    required this.quantity,
    required this.itemPrice,
    this.currency = 'INR',
    this.productName = '',
    this.imageUrl = '',
  });

  factory OrderProductItem.fromJson(Map<String, dynamic> json) {
    return OrderProductItem(
      productRetailerId: json['productRetailerId']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      productName: json['productName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }

  double get lineTotal => itemPrice * quantity;
}

class CatalogOrderModel {
  final String id;
  final String tenantId;
  final String catalogId;
  final String customerPhone;
  final String customerName;
  final List<OrderProductItem> productItems;
  final String orderText;
  final double totalAmount;
  final String currency;
  final String status; // new | viewed | fulfilled | cancelled
  final DateTime? createdAt;

  const CatalogOrderModel({
    required this.id,
    required this.tenantId,
    required this.catalogId,
    required this.customerPhone,
    this.customerName = '',
    required this.productItems,
    this.orderText = '',
    required this.totalAmount,
    this.currency = 'INR',
    this.status = 'new',
    this.createdAt,
  });

  factory CatalogOrderModel.fromJson(Map<String, dynamic> json) {
    final items = (json['productItems'] as List<dynamic>?)
            ?.map((e) => OrderProductItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CatalogOrderModel(
      id: json['_id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      catalogId: json['catalogId']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      productItems: items,
      orderText: json['orderText']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'new',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  CatalogOrderModel copyWith({String? status}) {
    return CatalogOrderModel(
      id: id,
      tenantId: tenantId,
      catalogId: catalogId,
      customerPhone: customerPhone,
      customerName: customerName,
      productItems: productItems,
      orderText: orderText,
      totalAmount: totalAmount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  String get formattedTotal => '$currency ${totalAmount.toStringAsFixed(2)}';

  bool get isNew => status == 'new';
}
