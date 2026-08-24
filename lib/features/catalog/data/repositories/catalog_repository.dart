import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';

class CatalogRepository {
  final Dio _dio;

  CatalogRepository(this._dio);

  // ── Commerce Settings ───────────────────────────────────────────────────────

  /// Fetches the commerce settings (cart & catalog visibility) for the
  /// business phone number configured on this tenant.
  Future<CatalogCommerceSettings> getCommerceSettings() async {
    try {
      final response = await _dio.get('/api/catalog/commerce-settings');
      if (response.statusCode == 200) {
        final data = response.data;
        // Handle both array and object responses
        if (data is List && data.isNotEmpty) {
          return CatalogCommerceSettings.fromJson(
              Map<String, dynamic>.from(data.first as Map));
        } else if (data is Map) {
          return CatalogCommerceSettings.fromJson(
              Map<String, dynamic>.from(data));
        }
      }
      return CatalogCommerceSettings.defaultSettings();
    } on DioException catch (e) {
      // Return defaults if endpoint not yet wired on backend
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 501 ||
          e.type == DioExceptionType.connectionTimeout) {
        return CatalogCommerceSettings.defaultSettings();
      }
      throw Exception(_extractError(e) ?? 'Failed to load commerce settings');
    }
  }

  /// Enables or disables cart / catalog visibility for the phone number.
  Future<void> updateCommerceSettings({
    bool? cartEnabled,
    bool? catalogVisible,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (cartEnabled != null) params['is_cart_enabled'] = cartEnabled;
      if (catalogVisible != null) params['is_catalog_visible'] = catalogVisible;

      await _dio.post('/api/catalog/commerce-settings', data: params);
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to update commerce settings');
    }
  }

  // ── Sample Test Products Fallback ─────────────────────────────────────────

  static final List<CatalogProduct> _sampleTestProducts = [
    CatalogProduct(
      retailerId: 'HEADPHONE-01',
      name: 'Wireless Noise-Canceling Headphones',
      description:
          'Premium over-ear Bluetooth headphones with active noise cancellation.',
      price: 149.99,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&q=80',
      isAvailable: true,
      brand: 'AudioPro',
    ),
    CatalogProduct(
      retailerId: 'WATCH-02',
      name: 'Smart Fitness Tracker Watch',
      description:
          'Heart rate monitor, GPS tracking, sleep analyzer, and 50m water resistance.',
      price: 89.50,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&q=80',
      isAvailable: true,
      brand: 'FitPulse',
    ),
    CatalogProduct(
      retailerId: 'BAG-03',
      name: 'Urban Leather Laptop Backpack',
      description:
          'Handcrafted genuine leather backpack with padded 15.6-inch laptop compartment.',
      price: 119.00,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500&q=80',
      isAvailable: true,
      brand: 'CraftedGoods',
    ),
    CatalogProduct(
      retailerId: 'SPEAKER-04',
      name: 'Portable Waterproof Bluetooth Speaker',
      description:
          '360-degree sound, deep bass, IPX7 waterproof rating, 20-hour playtime.',
      price: 59.99,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=500&q=80',
      isAvailable: true,
      brand: 'SoundWave',
    ),
    CatalogProduct(
      retailerId: 'SHOES-05',
      name: 'Ultra-Light Running Sneakers',
      description:
          'Breathable mesh upper with cushioned responsive foam sole for ultimate comfort.',
      price: 79.99,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500&q=80',
      isAvailable: true,
      brand: 'StrideStep',
    ),
    CatalogProduct(
      retailerId: 'GLASSES-06',
      name: 'Polarized UV400 Sunglasses',
      description:
          'Classic aviator frame with anti-glare polarized lenses and microfiber pouch.',
      price: 34.99,
      currency: 'USD',
      imageUrl:
          'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=500&q=80',
      isAvailable: true,
      brand: 'OpticStyle',
    ),
  ];

  static final List<CatalogProduct> _customAddedProducts = [];

  // ── Products ─────────────────────────────────────────────────────────────────

  /// Fetches products from the Meta catalog connected to this WABA.
  /// If no catalog is connected or backend is empty, returns sample test products + custom added items.
  Future<List<CatalogProduct>> fetchProducts({
    String? searchQuery,
    int limit = 50,
    String? after,
  }) async {
    List<CatalogProduct> products = [];
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (searchQuery != null && searchQuery.isNotEmpty) 'q': searchQuery,
        if (after != null) 'after': after,
      };
      final response = await _dio.get(
        '/api/catalog/products',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> items = [];

        if (data is List) {
          items = data;
        } else if (data is Map) {
          items = (data['data'] ?? data['products'] ?? []) as List<dynamic>;
        }

        products = items
            .map((json) =>
                CatalogProduct.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback to test catalog products when backend API is not yet wired
    }

    if (products.isEmpty) {
      products = [..._customAddedProducts, ..._sampleTestProducts];
    } else {
      products = [..._customAddedProducts, ...products];
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.retailerId.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }

    return products;
  }

  /// Adds a new product to the catalog.
  Future<CatalogProduct> addProduct(CatalogProduct product) async {
    try {
      final response = await _dio.post(
        '/api/catalog/products',
        data: {
          'retailer_id': product.retailerId,
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'currency': product.currency,
          'image_url': product.imageUrl,
          'availability': product.isAvailable ? 'in stock' : 'out of stock',
          'brand': product.brand,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          final created = CatalogProduct.fromJson(
              Map<String, dynamic>.from(response.data as Map));
          _customAddedProducts.insert(0, created);
          return created;
        }
      }
    } catch (_) {
      // Optimistic update for local UI testing
    }
    _customAddedProducts.insert(0, product);
    return product;
  }

  // ── Send Messages ─────────────────────────────────────────────────────────────

  /// Sends a Catalog Message (shows full catalog with View Catalog button).
  Future<String> sendCatalogMessage(CatalogMessageRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-catalog-message',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
      throw Exception('Failed to send catalog message');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send catalog message');
    }
  }

  /// Sends a Single Product Message (highlights one SKU).
  Future<String> sendSingleProduct(SingleProductRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-single-product',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
      throw Exception('Failed to send single product message');
    } on DioException catch (e) {
      throw Exception(
          _extractError(e) ?? 'Failed to send single product message');
    }
  }

  /// Sends a Multi-Product Message (up to 30 products across 10 sections).
  Future<String> sendMultiProduct(MultiProductRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-multi-product',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
      throw Exception('Failed to send multi-product message');
    } on DioException catch (e) {
      throw Exception(
          _extractError(e) ?? 'Failed to send multi-product message');
    }
  }

  /// Sends a Product Carousel (2–10 horizontally scrollable product cards).
  Future<String> sendProductCarousel(ProductCarouselRequest request) async {
    try {
      final response = await _dio.post(
        '/api/catalog/send-carousel',
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _extractMessageId(response.data);
      }
      throw Exception('Failed to send product carousel');
    } on DioException catch (e) {
      throw Exception(_extractError(e) ?? 'Failed to send product carousel');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _extractMessageId(dynamic data) {
    if (data is Map) {
      final messages = data['messages'] as List?;
      if (messages != null && messages.isNotEmpty) {
        return messages.first['id']?.toString() ?? 'sent';
      }
      return data['messageId']?.toString() ?? 'sent';
    }
    return 'sent';
  }

  String? _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['error'] as String? ?? data['message'] as String?;
    }
    return e.message;
  }
}
