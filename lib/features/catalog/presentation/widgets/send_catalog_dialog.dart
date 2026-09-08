import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

/// Dialog to send a catalog or single-product message to a recipient.
/// Used from Chat screen and Broadcast screen.
class SendCatalogDialog extends StatefulWidget {
  final String? recipientPhone;

  const SendCatalogDialog({super.key, this.recipientPhone});

  static Future<void> show(BuildContext context, {String? recipientPhone}) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CatalogBloc>(),
        child: SendCatalogDialog(recipientPhone: recipientPhone),
      ),
    );
  }

  @override
  State<SendCatalogDialog> createState() => _SendCatalogDialogState();
}

class _SendCatalogDialogState extends State<SendCatalogDialog> {
  final _phoneController = TextEditingController();
  final _bodyController = TextEditingController();
  String _sendType = 'catalog'; // 'catalog' | 'product'
  CatalogModel? _selectedCatalog;
  ProductModel? _selectedProduct;
  List<CatalogModel> _catalogs = [];
  List<ProductModel> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.recipientPhone ?? '';
    final state = context.read<CatalogBloc>().state;
    if (state is CatalogsLoaded) _catalogs = state.catalogs;
    if (state is ProductsLoaded) {
      _catalogs = state.catalogs;
      _selectedCatalog = state.selectedCatalog;
      _products = state.products;
    }
    if (_catalogs.isEmpty) {
      context.read<CatalogBloc>().add(FetchCatalogs());
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogsLoaded) setState(() => _catalogs = state.catalogs);
        if (state is ProductsLoaded) {
          setState(() {
            _catalogs = state.catalogs;
            _products = state.products;
            _isLoading = false;
          });
        }
        if (state is CatalogOperationSuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        }
        if (state is CatalogError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send Catalog Message',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: const Color(0xFF1A1A2E))),
                          Text('Share products with a customer',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),

                // Send type toggle
                Row(
                  children: [
                    _typeChip('catalog', Icons.collections_rounded, 'Full Catalog'),
                    const SizedBox(width: 8),
                    _typeChip('product', Icons.shopping_bag_outlined, 'Single Product'),
                  ],
                ),
                const SizedBox(height: 16),

                // Recipient
                _label('Recipient Phone'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('e.g. 919876543210', Icons.phone_rounded),
                ),
                const SizedBox(height: 14),

                // Catalog selector
                _label('Select Catalog'),
                const SizedBox(height: 6),
                DropdownButtonFormField<CatalogModel>(
                  value: _selectedCatalog,
                  decoration: _inputDecoration('Choose a catalog', Icons.storefront_outlined),
                  items: _catalogs.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.catalogName, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (c) {
                    setState(() {
                      _selectedCatalog = c;
                      _selectedProduct = null;
                      _products = [];
                    });
                    if (c != null && _sendType == 'product') {
                      setState(() => _isLoading = true);
                      context.read<CatalogBloc>().add(FetchProducts(c.catalogId));
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Product selector (only for single-product send)
                if (_sendType == 'product') ...[
                  _label('Select Product'),
                  const SizedBox(height: 6),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<ProductModel>(
                      value: _selectedProduct,
                      decoration: _inputDecoration('Choose a product', Icons.shopping_bag_outlined),
                      items: _products.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} — ${p.formattedPrice}', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (p) => setState(() => _selectedProduct = p),
                    ),
                  const SizedBox(height: 14),
                ],

                // Body text
                _label('Message Body'),
                const SizedBox(height: 6),
                TextField(
                  controller: _bodyController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    _sendType == 'catalog' ? 'Check out our catalog!' : 'Check out this product!',
                    Icons.message_outlined,
                  ),
                ),
                const SizedBox(height: 24),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text('Send ${_sendType == 'catalog' ? 'Catalog' : 'Product'} Message',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _send() {
    final to = _phoneController.text.trim();
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number is required')));
      return;
    }
    if (_selectedCatalog == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a catalog')));
      return;
    }

    setState(() => _isLoading = true);
    final bodyText = _bodyController.text.trim();

    if (_sendType == 'catalog') {
      final thumbnailId = _products.isNotEmpty ? _products.first.retailerId : '';
      if (thumbnailId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No products in catalog. Add a product first.')));
        setState(() => _isLoading = false);
        return;
      }
      context.read<CatalogBloc>().add(SendCatalogMessage(
        to: to,
        thumbnailRetailerId: thumbnailId,
        bodyText: bodyText.isNotEmpty ? bodyText : 'Check out our catalog!',
      ));
    } else {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product')));
        setState(() => _isLoading = false);
        return;
      }
      context.read<CatalogBloc>().add(SendProductMessage(
        to: to,
        catalogId: _selectedCatalog!.catalogId,
        productRetailerId: _selectedProduct!.retailerId,
        bodyText: bodyText,
      ));
    }
  }

  Widget _typeChip(String type, IconData icon, String label) {
    final selected = _sendType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sendType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: selected ? Colors.white : Colors.grey.shade700,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF374151)));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5)),
      );
}
