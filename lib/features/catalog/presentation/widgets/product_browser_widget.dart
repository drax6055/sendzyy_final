import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

/// Full-screen product browser that fetches products from the Meta catalog.
/// Used in both the Catalog panel tab and the chat attachment picker sheet.
class ProductBrowserWidget extends StatefulWidget {
  /// When non-null, tapping a product calls this instead of showing detail.
  final ValueChanged<CatalogProduct>? onProductSelected;

  /// If true, renders in compact mode (for bottom sheet picker).
  final bool isPickerMode;

  const ProductBrowserWidget({
    super.key,
    this.onProductSelected,
    this.isPickerMode = false,
  });

  @override
  State<ProductBrowserWidget> createState() => _ProductBrowserWidgetState();
}

class _ProductBrowserWidgetState extends State<ProductBrowserWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    // Debounced search
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_searchQuery == query) {
        context.read<CatalogBloc>().add(LoadProducts(searchQuery: query.isEmpty ? null : query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is! CatalogSettingsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Search + toggle bar
            _buildSearchBar(state),
            const SizedBox(height: 12),
            // Products grid/list
            Expanded(child: _buildProductsArea(state)),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(CatalogSettingsLoaded state) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile && !widget.isPickerMode) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search products by name or SKU...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => context.read<CatalogBloc>().add(LoadProducts()),
                icon: Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: _isGridView ? 'List view' : 'Grid view',
                onPressed: () => setState(() => _isGridView = !_isGridView),
                icon: Icon(
                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddProductDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Product', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search products by name or SKU...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        if (!widget.isPickerMode) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: _isGridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppTheme.secondaryColor,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<CatalogBloc>().add(LoadProducts()),
            icon: Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );
  }

  void _showAddProductDialog(BuildContext parentContext) {
    final isMobile = ResponsiveHelper.isMobile(parentContext);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    String currency = 'USD';
    bool isAvailable = true;

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 40,
              vertical: isMobile ? 16 : 24,
            ),
            child: Container(
              width: isMobile ? double.infinity : 500,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.add_shopping_cart_rounded,
                                color: AppTheme.primaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Product',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Add product details & image URL to catalog',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Image Preview Container
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: imageCtrl.text.trim().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        imageCtrl.text.trim(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_rounded,
                                              size: 40, color: Colors.redAccent),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined,
                                              size: 36, color: Colors.grey.shade400),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Image Preview',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Paste image link (HTTPS) below',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Product Name is required' : null,
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Wireless Bluetooth Speaker',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: skuCtrl,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
                              decoration: InputDecoration(
                                labelText: 'SKU / Retailer ID *',
                                hintText: 'e.g. SKU-101',
                                prefixIcon: const Icon(Icons.qr_code_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: brandCtrl,
                              decoration: InputDecoration(
                                labelText: 'Brand (optional)',
                                hintText: 'e.g. Acme',
                                prefixIcon: const Icon(Icons.branding_watermark_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Price required';
                                if (double.tryParse(v.trim()) == null) return 'Invalid price';
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Price *',
                                hintText: 'e.g. 49.99',
                                prefixIcon: const Icon(Icons.attach_money_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: currency,
                              items: ['USD', 'INR', 'EUR', 'GBP']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => currency = v);
                              },
                              decoration: InputDecoration(
                                labelText: 'Currency',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: imageCtrl,
                        onChanged: (_) => setDialogState(() {}),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Product image URL is required' : null,
                        decoration: InputDecoration(
                          labelText: 'Product Image URL *',
                          hintText: 'https://example.com/product-image.jpg',
                          prefixIcon: const Icon(Icons.link_rounded, size: 18),
                          suffixIcon: imageCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    imageCtrl.clear();
                                    setDialogState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Describe features and specifications...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Text('Stock Status:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          Switch.adaptive(
                            value: isAvailable,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) => setDialogState(() => isAvailable = v),
                          ),
                          Text(isAvailable ? 'In Stock' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAvailable ? const Color(0xFF059669) : Colors.red,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;

                            final newProduct = CatalogProduct(
                              retailerId: skuCtrl.text.trim(),
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              price: double.tryParse(priceCtrl.text.trim()),
                              currency: currency,
                              imageUrl: imageCtrl.text.trim(),
                              isAvailable: isAvailable,
                              brand: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
                            );

                            parentContext.read<CatalogBloc>().add(AddProductEvent(newProduct));
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Add Product to Catalog'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsArea(CatalogSettingsLoaded state) {
    if (state.isLoadingProducts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            const Text('Loading products from catalog...'),
          ],
        ),
      );
    }

    if (state.products.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CatalogBloc>().add(LoadProducts(searchQuery: _searchQuery.isEmpty ? null : _searchQuery));
      },
      child: _isGridView && !widget.isPickerMode
          ? _buildGrid(state.products)
          : _buildList(state.products),
    );
  }

  Widget _buildGrid(List<CatalogProduct> products) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 280,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => _ProductGridCard(
        product: products[i],
        onTap: () {
          if (widget.onProductSelected != null) {
            widget.onProductSelected!(products[i]);
          } else {
            _showProductDetailDialog(context, products[i]);
          }
        },
      ),
    );
  }

  Widget _buildList(List<CatalogProduct> products) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _ProductListTile(
        product: products[i],
        onTap: () {
          if (widget.onProductSelected != null) {
            widget.onProductSelected!(products[i]);
          } else {
            _showProductDetailDialog(context, products[i]);
          }
        },
      ),
    );
  }

  void _showProductDetailDialog(BuildContext context, CatalogProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (product.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    product.imageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (product.formattedPrice.isNotEmpty)
                    Text(
                      product.formattedPrice,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SKU: ${product.retailerId}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (product.description.isNotEmpty) ...[
                Text(
                  product.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Product images and prices are managed in Meta Commerce Manager.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearch ? 'No products match "$_searchQuery"' : 'No products found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Try a different search term or clear the filter.'
                : 'Make sure your Meta catalog is connected to your WABA\nand has products uploaded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.read<CatalogBloc>().add(LoadProducts()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Grid Card ─────────────────────────────────────────────────────────────────

class _ProductGridCard extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback? onTap;

  const _ProductGridCard({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1,
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1D1E),
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (product.formattedPrice.isNotEmpty)
                          Text(
                            product.formattedPrice,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.isAvailable
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.isAvailable ? 'In Stock' : 'Out',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: product.isAvailable
                                  ? const Color(0xFF059669)
                                  : Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${product.retailerId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey),
      ),
    );
  }
}

// ── List Tile ─────────────────────────────────────────────────────────────────

class _ProductListTile extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback? onTap;

  const _ProductListTile({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: product.imageUrl != null
              ? Image.network(product.imageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                  ))
              : Container(
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                ),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            'SKU: ${product.retailerId}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (product.formattedPrice.isNotEmpty)
            Text(
              product.formattedPrice,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: product.isAvailable
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.isAvailable ? 'In Stock' : 'Out',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: product.isAvailable
                    ? const Color(0xFF059669)
                    : Colors.red.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
