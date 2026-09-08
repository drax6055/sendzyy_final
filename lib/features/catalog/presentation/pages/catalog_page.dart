import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/pages/catalog_connect_page.dart';
import 'package:iFloraBuzz/features/catalog/presentation/pages/product_form_page.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_card.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/product_card.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/order_card.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/send_catalog_dialog.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/batch_import_dialog.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_order_model.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _newOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<CatalogBloc>().add(FetchCatalogs());
    context.read<CatalogBloc>().add(FetchOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
        if (state is CatalogOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        }
        if (state is OrdersLoaded) {
          setState(() => _newOrderCount = state.newCount);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _buildHeader(isMobile),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CatalogsTab(onCatalogSelected: (_) => _tabController.animateTo(1)),
                  _ProductsTab(),
                  _OrdersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WhatsApp Catalog',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: isMobile ? 18 : 20, color: const Color(0xFF1A1A2E)),
                ),
                Text(
                  'Manage your products and receive orders',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<CatalogBloc>(),
                    child: const CatalogConnectPage(),
                  ),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Add Catalog', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => SendCatalogDialog.show(context),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('Send Message', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, size: 18),
                SizedBox(width: 8),
                Text('Catalogs'),
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_rounded, size: 18),
                SizedBox(width: 8),
                Text('Products'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Orders'),
                if (_newOrderCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_newOrderCount',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Catalogs Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogsTab extends StatelessWidget {
  final void Function(CatalogModel) onCatalogSelected;

  const _CatalogsTab({required this.onCatalogSelected});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is CatalogLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<CatalogModel> catalogs = [];
        CatalogModel? selected;
        if (state is CatalogsLoaded) {
          catalogs = state.catalogs;
          selected = state.selectedCatalog;
        } else if (state is ProductsLoaded) {
          catalogs = state.catalogs;
          selected = state.selectedCatalog;
        }

        if (catalogs.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () async => context.read<CatalogBloc>().add(FetchCatalogs()),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            children: [
              ...catalogs.map((c) => CatalogCard(
                catalog: c,
                isSelected: selected?.catalogId == c.catalogId,
                onTap: () {
                  context.read<CatalogBloc>().add(SelectCatalog(c));
                  onCatalogSelected(c);
                },
                onUnlink: () => _confirmUnlink(context, c),
              )),
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      BlocProvider.value(value: context.read<CatalogBloc>(), child: const CatalogConnectPage()))),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Another Catalog'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withValues(alpha: 0.15), AppTheme.primaryColor.withValues(alpha: 0.05)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_rounded, size: 46, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            Text('No Catalogs Yet',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            Text(
              'Connect your WhatsApp Business Account to a Meta catalog to start selling products.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey.shade500, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  BlocProvider.value(value: context.read<CatalogBloc>(), child: const CatalogConnectPage()))),
              icon: const Icon(Icons.add_rounded),
              label: Text('Connect Your First Catalog', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(260, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnlink(BuildContext context, CatalogModel catalog) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unlink Catalog?'),
        content: Text('This will remove "${catalog.catalogName}" from your WhatsApp Business Account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CatalogBloc>().add(UnlinkCatalog(catalog.catalogId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Products Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is CatalogLoading) return const Center(child: CircularProgressIndicator());

        if (state is CatalogsLoaded && state.selectedCatalog == null) {
          return _buildSelectCatalogPrompt();
        }

        List<ProductModel> products = [];
        CatalogModel? selectedCatalog;

        if (state is ProductsLoaded) {
          products = state.products;
          selectedCatalog = state.selectedCatalog;
        } else if (state is CatalogsLoaded && state.selectedCatalog != null) {
          selectedCatalog = state.selectedCatalog;
        }

        if (selectedCatalog == null) return _buildSelectCatalogPrompt();

        final isWide = MediaQuery.of(context).size.width > 700;
        final crossAxisCount = isWide ? (MediaQuery.of(context).size.width > 1200 ? 4 : 3) : 2;

        return Stack(
          children: [
            products.isEmpty
                ? _buildNoProductsState(context, selectedCatalog)
                : RefreshIndicator(
                    onRefresh: () async => context.read<CatalogBloc>().add(FetchProducts(selectedCatalog!.catalogId)),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, i) {
                        final product = products[i];
                        return ProductCard(
                          product: product,
                          onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                            BlocProvider.value(value: context.read<CatalogBloc>(), child: ProductFormPage(catalogId: selectedCatalog!.catalogId, existingProduct: product)))),
                          onDelete: () => _confirmDelete(context, product),
                          onSend: () => SendCatalogDialog.show(context),
                        );
                      },
                    ),
                  ),
            Positioned(
              bottom: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'batch_import',
                    backgroundColor: Colors.green.shade600,
                    onPressed: () => BatchImportDialog.show(context, selectedCatalog!.catalogId),
                    child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'add_product',
                    backgroundColor: AppTheme.primaryColor,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>
                        BlocProvider.value(value: context.read<CatalogBloc>(), child: ProductFormPage(catalogId: selectedCatalog!.catalogId))),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: Text('Add Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectCatalogPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Select a Catalog',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Go to the Catalogs tab and select one to view its products',
              style: GoogleFonts.inter(color: Colors.grey.shade400), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoProductsState(BuildContext context, CatalogModel catalog) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text('No Products Yet',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text('Add products to "${catalog.catalogName}" to start sharing them on WhatsApp.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade500)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                BlocProvider.value(value: context.read<CatalogBloc>(), child: ProductFormPage(catalogId: catalog.catalogId)))),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add First Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(220, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.name}"? This will also remove it from Meta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (product.id != null) context.read<CatalogBloc>().add(DeleteProduct(product.id!));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Orders Tab
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is CatalogLoading) return const Center(child: CircularProgressIndicator());

        List<CatalogOrderModel> orders = [];
        if (state is OrdersLoaded) orders = state.orders;

        return Column(
          children: [
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _filterChip('All', null),
                  const SizedBox(width: 8),
                  _filterChip('New', 'new'),
                  const SizedBox(width: 8),
                  _filterChip('Viewed', 'viewed'),
                  const SizedBox(width: 8),
                  _filterChip('Fulfilled', 'fulfilled'),
                  const SizedBox(width: 8),
                  _filterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: orders.isEmpty
                  ? _buildEmptyOrders()
                  : RefreshIndicator(
                      onRefresh: () async => context.read<CatalogBloc>().add(FetchOrders(status: _filterStatus)),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: orders.length,
                        itemBuilder: (context, i) {
                          final order = orders[i];
                          return OrderCard(
                            order: order,
                            onTap: () => _showOrderDetail(context, order),
                            onStatusChange: (status) {
                              context.read<CatalogBloc>().add(UpdateOrderStatus(orderId: order.id, status: status));
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String? status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = status);
        context.read<CatalogBloc>().add(FetchOrders(status: status));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB)),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('No Orders Yet', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('When customers submit their cart via WhatsApp, orders will appear here.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, CatalogOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (__, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Order Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text('From: ${order.customerName.isNotEmpty ? order.customerName : order.customerPhone}',
                style: GoogleFonts.inter(color: Colors.grey.shade600)),
            if (order.customerName.isNotEmpty)
              Text(order.customerPhone, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(height: 24),
            Text('Items', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ...order.productItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName.isNotEmpty ? item.productName : item.productRetailerId,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('SKU: ${item.productRetailerId} • Qty: ${item.quantity}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Text(
                    '${item.currency} ${item.lineTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(order.formattedTotal, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryColor)),
              ],
            ),
            if (order.orderText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Customer Note', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade200)),
                child: Text(order.orderText, style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<CatalogBloc>().add(UpdateOrderStatus(orderId: order.id, status: 'fulfilled'));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Mark Fulfilled', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
