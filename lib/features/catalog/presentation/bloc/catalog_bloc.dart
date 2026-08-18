import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class CatalogEvent {}

class LoadCommerceSettings extends CatalogEvent {}

class UpdateCommerceSettings extends CatalogEvent {
  final bool? cartEnabled;
  final bool? catalogVisible;
  UpdateCommerceSettings({this.cartEnabled, this.catalogVisible});
}

class LoadProducts extends CatalogEvent {
  final String? searchQuery;
  LoadProducts({this.searchQuery});
}

class SendCatalogMessageEvent extends CatalogEvent {
  final CatalogMessageRequest request;
  SendCatalogMessageEvent(this.request);
}

class SendSingleProductEvent extends CatalogEvent {
  final SingleProductRequest request;
  SendSingleProductEvent(this.request);
}

class SendMultiProductEvent extends CatalogEvent {
  final MultiProductRequest request;
  SendMultiProductEvent(this.request);
}

class SendProductCarouselEvent extends CatalogEvent {
  final ProductCarouselRequest request;
  SendProductCarouselEvent(this.request);
}

class AddProductEvent extends CatalogEvent {
  final CatalogProduct product;
  AddProductEvent(this.product);
}

class ClearCatalogStatus extends CatalogEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class CatalogState {}

class CatalogInitial extends CatalogState {}

class CatalogSettingsLoading extends CatalogState {}

class CatalogSettingsLoaded extends CatalogState {
  final CatalogCommerceSettings settings;
  final List<CatalogProduct> products;
  final bool isLoadingProducts;
  final bool isSending;
  final String? successMessage;
  final String? errorMessage;

  CatalogSettingsLoaded({
    required this.settings,
    this.products = const [],
    this.isLoadingProducts = false,
    this.isSending = false,
    this.successMessage,
    this.errorMessage,
  });

  CatalogSettingsLoaded copyWith({
    CatalogCommerceSettings? settings,
    List<CatalogProduct>? products,
    bool? isLoadingProducts,
    bool? isSending,
    String? successMessage,
    bool clearSuccess = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogSettingsLoaded(
      settings: settings ?? this.settings,
      products: products ?? this.products,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isSending: isSending ?? this.isSending,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CatalogError extends CatalogState {
  final String message;
  CatalogError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final CatalogRepository _repository;

  CatalogBloc(this._repository) : super(CatalogInitial()) {
    on<LoadCommerceSettings>(_onLoadCommerceSettings);
    on<UpdateCommerceSettings>(_onUpdateCommerceSettings);
    on<LoadProducts>(_onLoadProducts);
    on<SendCatalogMessageEvent>(_onSendCatalogMessage);
    on<SendSingleProductEvent>(_onSendSingleProduct);
    on<SendMultiProductEvent>(_onSendMultiProduct);
    on<SendProductCarouselEvent>(_onSendProductCarousel);
    on<AddProductEvent>(_onAddProduct);
    on<ClearCatalogStatus>(_onClearStatus);
  }

  Future<void> _onAddProduct(
    AddProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    try {
      final added = await _repository.addProduct(event.product);
      if (current != null) {
        final updatedList = [added, ...current.products];
        emit(current.copyWith(
          products: updatedList,
          successMessage: 'Product "${added.name}" added to catalog!',
        ));
      }
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onLoadCommerceSettings(
    LoadCommerceSettings event,
    Emitter<CatalogState> emit,
  ) async {
    emit(CatalogSettingsLoading());
    try {
      final settings = await _repository.getCommerceSettings();
      emit(CatalogSettingsLoaded(settings: settings));
      // Also load products after settings
      add(LoadProducts());
    } catch (e) {
      emit(CatalogError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateCommerceSettings(
    UpdateCommerceSettings event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    try {
      await _repository.updateCommerceSettings(
        cartEnabled: event.cartEnabled,
        catalogVisible: event.catalogVisible,
      );
      // Optimistic update
      final newSettings = CatalogCommerceSettings(
        isCartEnabled: event.cartEnabled ??
            (current?.settings.isCartEnabled ?? true),
        isCatalogVisible: event.catalogVisible ??
            (current?.settings.isCatalogVisible ?? false),
        id: current?.settings.id ?? '',
      );
      if (current != null) {
        emit(current.copyWith(
          settings: newSettings,
          successMessage: 'Commerce settings updated',
        ));
      }
    } catch (e) {
      if (current != null) {
        emit(current.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      } else {
        emit(CatalogError(e.toString().replaceAll('Exception: ', '')));
      }
    }
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<CatalogState> emit,
  ) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    if (current != null) {
      emit(current.copyWith(isLoadingProducts: true, clearError: true));
    }
    try {
      final products = await _repository.fetchProducts(
        searchQuery: event.searchQuery,
      );
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          products: products,
          isLoadingProducts: false,
        ));
      }
    } catch (e) {
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          isLoadingProducts: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onSendCatalogMessage(
    SendCatalogMessageEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _sendWithFeedback(
      emit: emit,
      action: () => _repository.sendCatalogMessage(event.request),
      successMsg: 'Catalog message sent successfully!',
    );
  }

  Future<void> _onSendSingleProduct(
    SendSingleProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _sendWithFeedback(
      emit: emit,
      action: () => _repository.sendSingleProduct(event.request),
      successMsg: 'Single product message sent!',
    );
  }

  Future<void> _onSendMultiProduct(
    SendMultiProductEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _sendWithFeedback(
      emit: emit,
      action: () => _repository.sendMultiProduct(event.request),
      successMsg: 'Multi-product message sent!',
    );
  }

  Future<void> _onSendProductCarousel(
    SendProductCarouselEvent event,
    Emitter<CatalogState> emit,
  ) async {
    await _sendWithFeedback(
      emit: emit,
      action: () => _repository.sendProductCarousel(event.request),
      successMsg: 'Product carousel sent!',
    );
  }

  Future<void> _sendWithFeedback({
    required Emitter<CatalogState> emit,
    required Future<String> Function() action,
    required String successMsg,
  }) async {
    final current = state is CatalogSettingsLoaded
        ? state as CatalogSettingsLoaded
        : null;
    if (current != null) {
      emit(current.copyWith(isSending: true, clearError: true, clearSuccess: true));
    }
    try {
      await action();
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          isSending: false,
          successMessage: successMsg,
        ));
      }
    } catch (e) {
      if (state is CatalogSettingsLoaded) {
        emit((state as CatalogSettingsLoaded).copyWith(
          isSending: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  void _onClearStatus(ClearCatalogStatus event, Emitter<CatalogState> emit) {
    if (state is CatalogSettingsLoaded) {
      emit((state as CatalogSettingsLoaded).copyWith(
        clearSuccess: true,
        clearError: true,
      ));
    }
  }
}
