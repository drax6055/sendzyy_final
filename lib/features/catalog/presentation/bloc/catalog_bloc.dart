import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_order_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Events
// ─────────────────────────────────────────────────────────────────────────────

abstract class CatalogEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// Catalog events
class FetchCatalogs extends CatalogEvent {}

class CreateCatalog extends CatalogEvent {
  final String name;
  final String verticalType;
  CreateCatalog({required this.name, this.verticalType = 'commerce'});
  @override
  List<Object?> get props => [name, verticalType];
}

class LinkCatalog extends CatalogEvent {
  final String catalogId;
  final String? catalogName;
  LinkCatalog({required this.catalogId, this.catalogName});
  @override
  List<Object?> get props => [catalogId, catalogName];
}

class UnlinkCatalog extends CatalogEvent {
  final String catalogId;
  UnlinkCatalog(this.catalogId);
  @override
  List<Object?> get props => [catalogId];
}

class DeleteCatalog extends CatalogEvent {
  final String catalogId;
  DeleteCatalog(this.catalogId);
  @override
  List<Object?> get props => [catalogId];
}

class SelectCatalog extends CatalogEvent {
  final CatalogModel catalog;
  SelectCatalog(this.catalog);
  @override
  List<Object?> get props => [catalog.catalogId];
}

// Product events
class FetchProducts extends CatalogEvent {
  final String catalogId;
  FetchProducts(this.catalogId);
  @override
  List<Object?> get props => [catalogId];
}

class CreateProduct extends CatalogEvent {
  final String catalogId;
  final String retailerId;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String currency;
  final String availability;
  final String condition;
  final String link;
  final String brand;
  final String category;
  final double? salePrice;

  CreateProduct({
    required this.catalogId,
    required this.retailerId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description = '',
    this.currency = 'INR',
    this.availability = 'in stock',
    this.condition = 'new',
    this.link = '',
    this.brand = '',
    this.category = '',
    this.salePrice,
  });

  @override
  List<Object?> get props => [catalogId, retailerId, name];
}

class UpdateProduct extends CatalogEvent {
  final String productId;
  final Map<String, dynamic> updates;
  UpdateProduct({required this.productId, required this.updates});
  @override
  List<Object?> get props => [productId];
}

class DeleteProduct extends CatalogEvent {
  final String productId;
  DeleteProduct(this.productId);
  @override
  List<Object?> get props => [productId];
}

class BatchImportProducts extends CatalogEvent {
  final String catalogId;
  final List<Map<String, dynamic>> products;
  BatchImportProducts({required this.catalogId, required this.products});
  @override
  List<Object?> get props => [catalogId, products.length];
}

// Order events
class FetchOrders extends CatalogEvent {
  final String? status;
  final String? catalogId;
  FetchOrders({this.status, this.catalogId});
  @override
  List<Object?> get props => [status, catalogId];
}

class UpdateOrderStatus extends CatalogEvent {
  final String orderId;
  final String status;
  UpdateOrderStatus({required this.orderId, required this.status});
  @override
  List<Object?> get props => [orderId, status];
}

class CatalogOrderReceived extends CatalogEvent {
  final Map<String, dynamic> orderData;
  CatalogOrderReceived(this.orderData);
  @override
  List<Object?> get props => [orderData];
}

// Messaging events
class SendCatalogMessage extends CatalogEvent {
  final String to;
  final String thumbnailRetailerId;
  final String bodyText;
  SendCatalogMessage({required this.to, required this.thumbnailRetailerId, this.bodyText = 'Check out our catalog!'});
  @override
  List<Object?> get props => [to, thumbnailRetailerId];
}

class SendProductMessage extends CatalogEvent {
  final String to;
  final String catalogId;
  final String productRetailerId;
  final String bodyText;
  SendProductMessage({required this.to, required this.catalogId, required this.productRetailerId, this.bodyText = ''});
  @override
  List<Object?> get props => [to, catalogId, productRetailerId];
}

// ─────────────────────────────────────────────────────────────────────────────
//  States
// ─────────────────────────────────────────────────────────────────────────────

abstract class CatalogState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CatalogInitial extends CatalogState {}

class CatalogLoading extends CatalogState {}

class CatalogsLoaded extends CatalogState {
  final List<CatalogModel> catalogs;
  final CatalogModel? selectedCatalog;

  CatalogsLoaded({required this.catalogs, this.selectedCatalog});

  @override
  List<Object?> get props => [catalogs, selectedCatalog?.catalogId];

  CatalogsLoaded copyWith({List<CatalogModel>? catalogs, CatalogModel? selectedCatalog}) {
    return CatalogsLoaded(
      catalogs: catalogs ?? this.catalogs,
      selectedCatalog: selectedCatalog ?? this.selectedCatalog,
    );
  }
}

class ProductsLoaded extends CatalogState {
  final List<CatalogModel> catalogs;
  final CatalogModel selectedCatalog;
  final List<ProductModel> products;

  ProductsLoaded({required this.catalogs, required this.selectedCatalog, required this.products});

  @override
  List<Object?> get props => [catalogs, selectedCatalog.catalogId, products];

  ProductsLoaded copyWith({List<ProductModel>? products}) {
    return ProductsLoaded(
      catalogs: catalogs,
      selectedCatalog: selectedCatalog,
      products: products ?? this.products,
    );
  }
}

class OrdersLoaded extends CatalogState {
  final List<CatalogOrderModel> orders;
  final int newCount;

  OrdersLoaded({required this.orders, this.newCount = 0});

  @override
  List<Object?> get props => [orders, newCount];
}

class CatalogOperationSuccess extends CatalogState {
  final String message;
  CatalogOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class CatalogError extends CatalogState {
  final String message;
  CatalogError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
//  BLoC
// ─────────────────────────────────────────────────────────────────────────────

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final CatalogRepository _repository;

  List<CatalogModel> _catalogs = [];
  CatalogModel? _selectedCatalog;

  CatalogBloc(this._repository) : super(CatalogInitial()) {
    on<FetchCatalogs>(_onFetchCatalogs);
    on<CreateCatalog>(_onCreateCatalog);
    on<LinkCatalog>(_onLinkCatalog);
    on<UnlinkCatalog>(_onUnlinkCatalog);
    on<DeleteCatalog>(_onDeleteCatalog);
    on<SelectCatalog>(_onSelectCatalog);
    on<FetchProducts>(_onFetchProducts);
    on<CreateProduct>(_onCreateProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<BatchImportProducts>(_onBatchImport);
    on<FetchOrders>(_onFetchOrders);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<CatalogOrderReceived>(_onCatalogOrderReceived);
    on<SendCatalogMessage>(_onSendCatalogMessage);
    on<SendProductMessage>(_onSendProductMessage);
  }

  Future<void> _onFetchCatalogs(FetchCatalogs event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      _catalogs = await _repository.fetchCatalogs();
      emit(CatalogsLoaded(catalogs: _catalogs, selectedCatalog: _selectedCatalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onCreateCatalog(CreateCatalog event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      final newCatalog = await _repository.createCatalog(name: event.name, verticalType: event.verticalType);
      _catalogs = [newCatalog, ..._catalogs];
      _selectedCatalog = newCatalog;
      emit(CatalogOperationSuccess('Catalog "${event.name}" created successfully!'));
      emit(CatalogsLoaded(catalogs: _catalogs, selectedCatalog: _selectedCatalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onLinkCatalog(LinkCatalog event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      await _repository.linkCatalog(catalogId: event.catalogId, catalogName: event.catalogName);
      add(FetchCatalogs());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onUnlinkCatalog(UnlinkCatalog event, Emitter<CatalogState> emit) async {
    try {
      await _repository.unlinkCatalog(event.catalogId);
      _catalogs = _catalogs.map((c) => c.catalogId == event.catalogId ? c.copyWith(isLinked: false) : c).toList();
      if (_selectedCatalog?.catalogId == event.catalogId) _selectedCatalog = null;
      emit(CatalogOperationSuccess('Catalog unlinked'));
      emit(CatalogsLoaded(catalogs: _catalogs, selectedCatalog: _selectedCatalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onDeleteCatalog(DeleteCatalog event, Emitter<CatalogState> emit) async {
    try {
      await _repository.deleteCatalog(event.catalogId);
      _catalogs = _catalogs.where((c) => c.catalogId != event.catalogId).toList();
      if (_selectedCatalog?.catalogId == event.catalogId) {
        _selectedCatalog = _catalogs.isNotEmpty ? _catalogs.first : null;
      }
      emit(CatalogOperationSuccess('Catalog deleted'));
      emit(CatalogsLoaded(catalogs: _catalogs, selectedCatalog: _selectedCatalog));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  void _onSelectCatalog(SelectCatalog event, Emitter<CatalogState> emit) {
    _selectedCatalog = event.catalog;
    emit(CatalogsLoaded(catalogs: _catalogs, selectedCatalog: _selectedCatalog));
    add(FetchProducts(event.catalog.catalogId));
  }

  Future<void> _onFetchProducts(FetchProducts event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      final products = await _repository.fetchProducts(event.catalogId);
      final catalog = _catalogs.firstWhere(
        (c) => c.catalogId == event.catalogId,
        orElse: () => CatalogModel(catalogId: event.catalogId, catalogName: ''),
      );
      _selectedCatalog = catalog;
      emit(ProductsLoaded(catalogs: _catalogs, selectedCatalog: catalog, products: products));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onCreateProduct(CreateProduct event, Emitter<CatalogState> emit) async {
    final previousState = state;
    emit(CatalogLoading());
    try {
      final product = await _repository.createProduct(
        catalogId: event.catalogId,
        retailerId: event.retailerId,
        name: event.name,
        price: event.price,
        imageUrl: event.imageUrl,
        description: event.description,
        currency: event.currency,
        availability: event.availability,
        condition: event.condition,
        link: event.link,
        brand: event.brand,
        category: event.category,
        salePrice: event.salePrice,
      );
      emit(CatalogOperationSuccess('Product "${product.name}" added!'));
      add(FetchProducts(event.catalogId));
    } catch (e) {
      if (previousState is ProductsLoaded) emit(previousState);
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onUpdateProduct(UpdateProduct event, Emitter<CatalogState> emit) async {
    final previousState = state;
    try {
      final updated = await _repository.updateProduct(event.productId, event.updates);
      emit(CatalogOperationSuccess('Product updated!'));
      if (previousState is ProductsLoaded) {
        final products = previousState.products
            .map((p) => p.id == event.productId ? updated : p)
            .toList();
        emit(previousState.copyWith(products: products));
      }
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onDeleteProduct(DeleteProduct event, Emitter<CatalogState> emit) async {
    final previousState = state;
    try {
      await _repository.deleteProduct(event.productId);
      emit(CatalogOperationSuccess('Product deleted'));
      if (previousState is ProductsLoaded) {
        final products = previousState.products.where((p) => p.id != event.productId).toList();
        emit(previousState.copyWith(products: products));
      }
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onBatchImport(BatchImportProducts event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      final result = await _repository.batchImportProducts(catalogId: event.catalogId, products: event.products);
      emit(CatalogOperationSuccess('Imported ${result['inserted']} products!'));
      add(FetchProducts(event.catalogId));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onFetchOrders(FetchOrders event, Emitter<CatalogState> emit) async {
    emit(CatalogLoading());
    try {
      final result = await _repository.fetchOrders(status: event.status, catalogId: event.catalogId);
      final orders = result['orders'] as List<CatalogOrderModel>;
      final newCount = result['newCount'] as int;
      emit(OrdersLoaded(orders: orders, newCount: newCount));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(UpdateOrderStatus event, Emitter<CatalogState> emit) async {
    try {
      final updated = await _repository.updateOrderStatus(event.orderId, event.status);
      if (state is OrdersLoaded) {
        final orders = (state as OrdersLoaded).orders
            .map((o) => o.id == event.orderId ? updated : o)
            .toList();
        final newCount = orders.where((o) => o.status == 'new').length;
        emit(OrdersLoaded(orders: orders, newCount: newCount));
      }
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  void _onCatalogOrderReceived(CatalogOrderReceived event, Emitter<CatalogState> emit) {
    // Re-fetch orders to include the new one
    if (state is OrdersLoaded) {
      add(FetchOrders());
    }
  }

  Future<void> _onSendCatalogMessage(SendCatalogMessage event, Emitter<CatalogState> emit) async {
    try {
      await _repository.sendCatalogMessage(
        to: event.to,
        thumbnailProductRetailerId: event.thumbnailRetailerId,
        bodyText: event.bodyText,
      );
      emit(CatalogOperationSuccess('Catalog message sent!'));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onSendProductMessage(SendProductMessage event, Emitter<CatalogState> emit) async {
    try {
      await _repository.sendProductMessage(
        to: event.to,
        catalogId: event.catalogId,
        productRetailerId: event.productRetailerId,
        bodyText: event.bodyText,
      );
      emit(CatalogOperationSuccess('Product message sent!'));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }
}
