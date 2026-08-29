// Catalog Commerce Settings
class CatalogCommerceSettings {
  final bool isCartEnabled;
  final bool isCatalogVisible;
  final String id;

  CatalogCommerceSettings({
    required this.isCartEnabled,
    required this.isCatalogVisible,
    required this.id,
  });

  factory CatalogCommerceSettings.fromJson(Map<String, dynamic> json) {
    return CatalogCommerceSettings(
      isCartEnabled: json['is_cart_enabled'] ?? false,
      isCatalogVisible: json['is_catalog_visible'] ?? false,
      id: json['id']?.toString() ?? '',
    );
  }

  factory CatalogCommerceSettings.defaultSettings() {
    return CatalogCommerceSettings(
      isCartEnabled: true,
      isCatalogVisible: false,
      id: '',
    );
  }
}

// A single product from the Meta catalog
class CatalogProduct {
  final String retailerId; // product_retailer_id / content_id / SKU
  final String name;
  final String description;
  final double? price;
  final String? currency;
  final String? imageUrl;
  final bool isAvailable;
  final String? brand;

  CatalogProduct({
    required this.retailerId,
    required this.name,
    required this.description,
    this.price,
    this.currency,
    this.imageUrl,
    this.isAvailable = true,
    this.brand,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    double? parsedPrice;
    final rawPrice = json['price'] ?? json['sale_price'];
    if (rawPrice != null) {
      parsedPrice = double.tryParse(rawPrice.toString());
      // Meta returns price as integer cents sometimes
      if (parsedPrice != null && parsedPrice > 100) {
        parsedPrice = parsedPrice / 100;
      }
    }

    return CatalogProduct(
      retailerId: json['retailer_id']?.toString() ??
          json['id']?.toString() ??
          json['product_retailer_id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: parsedPrice,
      currency: json['currency']?.toString(),
      imageUrl: json['image_url']?.toString() ??
          json['imageUrl']?.toString(),
      isAvailable: json['availability']?.toString() != 'out of stock',
      brand: json['brand']?.toString(),
    );
  }

  String get formattedPrice {
    if (price == null) return '';
    final symbol = _currencySymbol(currency);
    return '$symbol${price!.toStringAsFixed(2)}';
  }

  String _currencySymbol(String? currency) {
    switch (currency?.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency != null ? '$currency ' : '';
    }
  }
}

// ── Message Request Models ────────────────────────────────────────────────────

/// Catalog Message — shows full catalog with thumbnail + "View catalog" button
class CatalogMessageRequest {
  final String to;
  final String bodyText;
  final String? footerText;
  final String? thumbnailProductRetailerId;

  CatalogMessageRequest({
    required this.to,
    required this.bodyText,
    this.footerText,
    this.thumbnailProductRetailerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
      if (thumbnailProductRetailerId != null &&
          thumbnailProductRetailerId!.isNotEmpty)
        'thumbnailProductRetailerId': thumbnailProductRetailerId,
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'catalog_message',
        'body': {'text': bodyText},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'name': 'catalog_message',
          if (thumbnailProductRetailerId != null &&
              thumbnailProductRetailerId!.isNotEmpty)
            'parameters': {
              'thumbnail_product_retailer_id': thumbnailProductRetailerId!,
            },
        },
      },
    };
  }
}

/// Single Product Message — highlights one specific product
class SingleProductRequest {
  final String to;
  final String catalogId;
  final String productRetailerId;
  final String? bodyText;
  final String? footerText;

  SingleProductRequest({
    required this.to,
    required this.catalogId,
    required this.productRetailerId,
    this.bodyText,
    this.footerText,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'catalogId': catalogId,
      'productRetailerId': productRetailerId,
      if (bodyText != null && bodyText!.isNotEmpty) 'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'product',
        if (bodyText != null && bodyText!.isNotEmpty)
          'body': {'text': bodyText!},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'catalog_id': catalogId,
          'product_retailer_id': productRetailerId,
        },
      },
    };
  }
}

/// A section within a Multi-Product Message
class MultiProductSection {
  final String title;
  final List<String> productRetailerIds;

  MultiProductSection({
    required this.title,
    required this.productRetailerIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'productItems': productRetailerIds.map((id) => {'productRetailerId': id}).toList(),
    };
  }
}

/// Multi-Product Message — up to 30 products across 10 sections
class MultiProductRequest {
  final String to;
  final String catalogId;
  final String headerText;
  final String bodyText;
  final String? footerText;
  final List<MultiProductSection> sections;

  MultiProductRequest({
    required this.to,
    required this.catalogId,
    required this.headerText,
    required this.bodyText,
    this.footerText,
    required this.sections,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'catalogId': catalogId,
      'headerText': headerText,
      'bodyText': bodyText,
      if (footerText != null && footerText!.isNotEmpty) 'footerText': footerText,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'product_list',
        'header': {'type': 'text', 'text': headerText},
        'body': {'text': bodyText},
        if (footerText != null && footerText!.isNotEmpty)
          'footer': {'text': footerText!},
        'action': {
          'catalog_id': catalogId,
          'sections': sections
              .map((s) => {
                    'title': s.title,
                    'product_items': s.productRetailerIds
                        .map((id) => {'product_retailer_id': id})
                        .toList(),
                  })
              .toList(),
        },
      },
    };
  }
}

/// A single card in a product carousel
class ProductCarouselCard {
  final int cardIndex;
  final String productRetailerId;
  final String catalogId;

  ProductCarouselCard({
    required this.cardIndex,
    required this.productRetailerId,
    required this.catalogId,
  });

  Map<String, dynamic> toJson() {
    return {
      'cardIndex': cardIndex,
      'productRetailerId': productRetailerId,
      'catalogId': catalogId,
    };
  }
}

/// Product Carousel Message — 2–10 horizontally scrollable product cards
class ProductCarouselRequest {
  final String to;
  final String bodyText;
  final List<ProductCarouselCard> cards;

  ProductCarouselRequest({
    required this.to,
    required this.bodyText,
    required this.cards,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'bodyText': bodyText,
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }

  Map<String, dynamic> toMetaInteractivePayload() {
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': {
        'type': 'carousel',
        'body': {'text': bodyText},
        'action': {
          'cards': cards
              .map((c) => {
                    'card_index': c.cardIndex,
                    'components': [
                      {
                        'type': 'button',
                        'sub_type': 'product',
                        'parameters': [
                          {
                            'type': 'product',
                            'product': {
                              'catalog_id': c.catalogId,
                              'product_retailer_id': c.productRetailerId,
                            },
                          },
                        ],
                      },
                    ],
                  })
              .toList(),
        },
      },
    };
  }
}
