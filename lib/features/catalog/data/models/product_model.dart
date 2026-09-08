class ProductModel {
  final String? id; // MongoDB _id
  final String catalogId;
  final String retailerId;
  final String productId; // Meta product ID
  final String name;
  final String description;
  final double price;
  final String currency;
  final String imageUrl;
  final String availability;
  final String condition;
  final String link;
  final String brand;
  final String category;
  final double? salePrice;
  final bool isSynced;
  final DateTime? createdAt;

  const ProductModel({
    this.id,
    required this.catalogId,
    required this.retailerId,
    this.productId = '',
    required this.name,
    this.description = '',
    required this.price,
    this.currency = 'INR',
    required this.imageUrl,
    this.availability = 'in stock',
    this.condition = 'new',
    this.link = '',
    this.brand = '',
    this.category = '',
    this.salePrice,
    this.isSynced = false,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id']?.toString(),
      catalogId: json['catalogId']?.toString() ?? '',
      retailerId: json['retailerId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      imageUrl: json['imageUrl']?.toString() ?? '',
      availability: json['availability']?.toString() ?? 'in stock',
      condition: json['condition']?.toString() ?? 'new',
      link: json['link']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      salePrice: json['salePrice'] != null ? (json['salePrice'] as num).toDouble() : null,
      isSynced: json['isSynced'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'catalogId': catalogId,
        'retailerId': retailerId,
        'name': name,
        'description': description,
        'price': price,
        'currency': currency,
        'imageUrl': imageUrl,
        'availability': availability,
        'condition': condition,
        'link': link,
        'brand': brand,
        'category': category,
        if (salePrice != null) 'salePrice': salePrice,
      };

  ProductModel copyWith({
    String? id,
    String? catalogId,
    String? retailerId,
    String? productId,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? imageUrl,
    String? availability,
    String? condition,
    String? link,
    String? brand,
    String? category,
    double? salePrice,
    bool? isSynced,
  }) {
    return ProductModel(
      id: id ?? this.id,
      catalogId: catalogId ?? this.catalogId,
      retailerId: retailerId ?? this.retailerId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      availability: availability ?? this.availability,
      condition: condition ?? this.condition,
      link: link ?? this.link,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      salePrice: salePrice ?? this.salePrice,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
    );
  }

  String get formattedPrice {
    final effectivePrice = salePrice ?? price;
    return '$currency ${effectivePrice.toStringAsFixed(2)}';
  }
}
