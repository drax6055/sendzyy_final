import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_order_model.dart';

class CatalogRepository {
  final Dio _dio;

  CatalogRepository(this._dio);

  // ─── Catalog CRUD ────────────────────────────────────────────────────────────

  Future<List<CatalogModel>> fetchCatalogs() async {
    try {
      final response = await _dio.get('/api/catalog/list');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['catalogs'] ?? [];
        return data.map((e) => CatalogModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch catalogs');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch catalogs'));
    }
  }

  Future<CatalogModel> createCatalog({required String name, String verticalType = 'commerce'}) async {
    try {
      final response = await _dio.post('/api/catalog/create', data: {
        'name': name,
        'verticalType': verticalType,
      });
      if (response.statusCode == 200) {
        return CatalogModel.fromJson(response.data['catalog'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error'] ?? 'Failed to create catalog');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to create catalog'));
    }
  }

  Future<Map<String, dynamic>> linkCatalog({required String catalogId, String? catalogName}) async {
    try {
      final response = await _dio.post('/api/catalog/link', data: {
        'catalogId': catalogId,
        if (catalogName != null) 'catalogName': catalogName,
      });
      if (response.statusCode == 200) return response.data as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to link catalog');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to link catalog'));
    }
  }

  Future<void> unlinkCatalog(String catalogId) async {
    try {
      final response = await _dio.delete('/api/catalog/$catalogId/unlink');
      if (response.statusCode != 200) {
        throw Exception(response.data['error'] ?? 'Failed to unlink catalog');
      }
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to unlink catalog'));
    }
  }

  // ─── Product CRUD ────────────────────────────────────────────────────────────

  Future<List<ProductModel>> fetchProducts(String catalogId, {int page = 1, int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/api/catalog/$catalogId/products',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['products'] ?? [];
        return data.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch products');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch products'));
    }
  }

  Future<ProductModel> createProduct({
    required String catalogId,
    required String retailerId,
    required String name,
    required double price,
    required String imageUrl,
    String description = '',
    String currency = 'INR',
    String availability = 'in stock',
    String condition = 'new',
    String link = '',
    String brand = '',
    String category = '',
    double? salePrice,
  }) async {
    try {
      final response = await _dio.post('/api/catalog/$catalogId/products', data: {
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
      });
      if (response.statusCode == 201) {
        return ProductModel.fromJson(response.data['product'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error'] ?? 'Failed to create product');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to create product'));
    }
  }

  Future<ProductModel> updateProduct(String productId, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.put('/api/catalog/products/$productId', data: updates);
      if (response.statusCode == 200) {
        return ProductModel.fromJson(response.data['product'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error'] ?? 'Failed to update product');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to update product'));
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final response = await _dio.delete('/api/catalog/products/$productId');
      if (response.statusCode != 200) {
        throw Exception(response.data['error'] ?? 'Failed to delete product');
      }
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to delete product'));
    }
  }

  /// Upload a product image to S3 and return its public URL
  Future<String> uploadProductImage({
    Uint8List? imageBytes,
    String? imagePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      FormData formData;

      if (kIsWeb && imageBytes != null) {
        formData = FormData.fromMap({
          'image': MultipartFile.fromBytes(imageBytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
        });
      } else if (imagePath != null) {
        formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(imagePath, filename: fileName, contentType: DioMediaType.parse(mimeType)),
        });
      } else {
        throw Exception('No image source provided');
      }

      final response = await _dio.post('/api/catalog/upload-image', data: formData);
      if (response.statusCode == 200) {
        return response.data['imageUrl'] as String;
      }
      throw Exception(response.data['error'] ?? 'Upload failed');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to upload image'));
    }
  }

  Future<Map<String, dynamic>> batchImportProducts({
    required String catalogId,
    required List<Map<String, dynamic>> products,
  }) async {
    try {
      final response = await _dio.post('/api/catalog/$catalogId/products/batch', data: {'products': products});
      if (response.statusCode == 200) return response.data as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Batch import failed');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to batch import products'));
    }
  }

  // ─── Orders ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchOrders({String? status, int page = 1, int limit = 30, String? catalogId}) async {
    try {
      final response = await _dio.get('/api/catalog/orders', queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
        if (catalogId != null) 'catalogId': catalogId,
      });
      if (response.statusCode == 200) {
        final List<dynamic> raw = response.data['orders'] ?? [];
        return {
          'orders': raw.map((e) => CatalogOrderModel.fromJson(e as Map<String, dynamic>)).toList(),
          'total': response.data['total'] ?? 0,
          'newCount': response.data['newCount'] ?? 0,
        };
      }
      throw Exception('Failed to fetch orders');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to fetch orders'));
    }
  }

  Future<CatalogOrderModel> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _dio.patch('/api/catalog/orders/$orderId', data: {'status': status});
      if (response.statusCode == 200) {
        return CatalogOrderModel.fromJson(response.data['order'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error'] ?? 'Failed to update order');
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to update order status'));
    }
  }

  // ─── Messaging ───────────────────────────────────────────────────────────────

  Future<String?> sendCatalogMessage({
    required String to,
    required String thumbnailProductRetailerId,
    String bodyText = 'Check out our catalog!',
  }) async {
    try {
      final response = await _dio.post('/api/catalog/send-catalog-message', data: {
        'to': to,
        'bodyText': bodyText,
        'thumbnailProductRetailerId': thumbnailProductRetailerId,
      });
      if (response.statusCode == 200) return response.data['messageId'] as String?;
      throw Exception(response.data['error']);
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to send catalog message'));
    }
  }

  Future<String?> sendProductMessage({
    required String to,
    required String catalogId,
    required String productRetailerId,
    String bodyText = '',
  }) async {
    try {
      final response = await _dio.post('/api/catalog/send-product-message', data: {
        'to': to,
        'catalogId': catalogId,
        'productRetailerId': productRetailerId,
        if (bodyText.isNotEmpty) 'bodyText': bodyText,
      });
      if (response.statusCode == 200) return response.data['messageId'] as String?;
      throw Exception(response.data['error']);
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to send product message'));
    }
  }

  Future<String?> sendMultiProductMessage({
    required String to,
    required String catalogId,
    required List<Map<String, dynamic>> sections,
    String headerText = 'Our Products',
    String bodyText = 'Select items to add to your cart',
    String footerText = '',
  }) async {
    try {
      final response = await _dio.post('/api/catalog/send-multiproduct-message', data: {
        'to': to,
        'catalogId': catalogId,
        'sections': sections,
        'headerText': headerText,
        'bodyText': bodyText,
        if (footerText.isNotEmpty) 'footerText': footerText,
      });
      if (response.statusCode == 200) return response.data['messageId'] as String?;
      throw Exception(response.data['error']);
    } catch (e) {
      throw Exception(_parseError(e, 'Failed to send multi-product message'));
    }
  }

  // ─── Helper ──────────────────────────────────────────────────────────────────
  String _parseError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      return e.message ?? fallback;
    }
    return e.toString();
  }
}
