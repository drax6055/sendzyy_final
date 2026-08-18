import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/product_browser_widget.dart';

/// Bottom sheet picker that lets an agent select a product and send
/// catalog/product messages directly from the Chat panel.
class CatalogProductPickerSheet extends StatefulWidget {
  /// The contact ID (phone number) to send the message to.
  final String contactId;

  const CatalogProductPickerSheet({super.key, required this.contactId});

  @override
  State<CatalogProductPickerSheet> createState() =>
      _CatalogProductPickerSheetState();
}

class _CatalogProductPickerSheetState
    extends State<CatalogProductPickerSheet> {
  CatalogProduct? _selectedProduct;
  _SendMode _sendMode = _SendMode.catalog;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Catalog Message',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Choose what to send to this contact',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Mode selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ModeSelector(
                  selected: _sendMode,
                  onChanged: (m) => setState(() {
                    _sendMode = m;
                    _selectedProduct = null;
                  }),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_sendMode) {
      case _SendMode.catalog:
        return _CatalogQuickSend(contactId: widget.contactId);
      case _SendMode.singleProduct:
        return _SingleProductQuickSend(
          contactId: widget.contactId,
          selectedProduct: _selectedProduct,
          onPickProduct: _pickProduct,
        );
      case _SendMode.multiProduct:
        return _MultiProductQuickSend(contactId: widget.contactId);
      case _SendMode.carousel:
        return _CarouselQuickSend(contactId: widget.contactId);
    }
  }

  void _pickProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<CatalogBloc>(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select a Product',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ProductBrowserWidget(
                    isPickerMode: true,
                    onProductSelected: (p) {
                      setState(() => _selectedProduct = p);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode Selector ─────────────────────────────────────────────────────────────

enum _SendMode { catalog, singleProduct, multiProduct, carousel }

class _ModeSelector extends StatelessWidget {
  final _SendMode selected;
  final ValueChanged<_SendMode> onChanged;

  const _ModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final modes = [
      (icon: Icons.storefront_rounded, label: 'Catalog', mode: _SendMode.catalog),
      (icon: Icons.inventory_2_outlined, label: 'Single', mode: _SendMode.singleProduct),
      (icon: Icons.grid_view_rounded, label: 'Multi', mode: _SendMode.multiProduct),
      (icon: Icons.view_carousel_rounded, label: 'Carousel', mode: _SendMode.carousel),
    ];
    return Row(
      children: modes
          .map((m) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => onChanged(m.mode),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected == m.mode
                            ? AppTheme.primaryColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(m.icon,
                              size: 18,
                              color: selected == m.mode
                                  ? Colors.white
                                  : Colors.grey.shade600),
                          const SizedBox(height: 2),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected == m.mode
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Quick-send forms inside the picker sheet ──────────────────────────────────

class _CatalogQuickSend extends StatefulWidget {
  final String contactId;
  const _CatalogQuickSend({required this.contactId});
  @override
  State<_CatalogQuickSend> createState() => _CatalogQuickSendState();
}

class _CatalogQuickSendState extends State<_CatalogQuickSend> {
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (ctx, state) {
        if (state is CatalogSettingsLoaded && state.successMessage != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      },
      builder: (ctx, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send full catalog view to this contact.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 3,
                maxLength: 1024,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Body text is required'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Message Body *',
                  hintText: 'e.g. Check out our catalog!',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSending
                      ? null
                      : () {
                          if (!_formKey.currentState!.validate()) return;
                          ctx.read<CatalogBloc>().add(
                                SendCatalogMessageEvent(
                                  CatalogMessageRequest(
                                    to: widget.contactId,
                                    bodyText: _bodyCtrl.text.trim(),
                                  ),
                                ),
                              );
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(isSending ? 'Sending...' : 'Send Catalog'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SingleProductQuickSend extends StatefulWidget {
  final String contactId;
  final CatalogProduct? selectedProduct;
  final VoidCallback onPickProduct;

  const _SingleProductQuickSend({
    required this.contactId,
    required this.selectedProduct,
    required this.onPickProduct,
  });

  @override
  State<_SingleProductQuickSend> createState() =>
      _SingleProductQuickSendState();
}

class _SingleProductQuickSendState extends State<_SingleProductQuickSend> {
  final _catalogCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _catalogCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (ctx, state) {
        if (state is CatalogSettingsLoaded && state.successMessage != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      },
      builder: (ctx, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product selection
              InkWell(
                onTap: widget.onPickProduct,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.selectedProduct != null
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.selectedProduct != null
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: widget.selectedProduct != null
                      ? Row(
                          children: [
                            if (widget.selectedProduct!.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.selectedProduct!.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.inventory_2_outlined),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.selectedProduct!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'SKU: ${widget.selectedProduct!.retailerId}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit_outlined,
                                color: AppTheme.primaryColor, size: 18),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 10),
                            Text('Tap to select a product from catalog',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _catalogCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Catalog ID required' : null,
                decoration: InputDecoration(
                  labelText: 'Catalog ID *',
                  hintText: 'e.g. 1537566713439863',
                  prefixIcon: const Icon(Icons.storage_rounded, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Body Text (optional)',
                  hintText: 'e.g. This item is perfect for you!',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (isSending || widget.selectedProduct == null)
                      ? null
                      : () {
                          if (!_formKey.currentState!.validate()) return;
                          ctx.read<CatalogBloc>().add(
                                SendSingleProductEvent(
                                  SingleProductRequest(
                                    to: widget.contactId,
                                    catalogId: _catalogCtrl.text.trim(),
                                    productRetailerId:
                                        widget.selectedProduct!.retailerId,
                                    bodyText: _bodyCtrl.text.trim().isEmpty
                                        ? null
                                        : _bodyCtrl.text.trim(),
                                  ),
                                ),
                              );
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    widget.selectedProduct == null
                        ? 'Select a product first'
                        : (isSending ? 'Sending...' : 'Send Product'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MultiProductQuickSend extends StatelessWidget {
  final String contactId;
  const _MultiProductQuickSend({required this.contactId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'For multi-product messages with multiple sections, use the full Catalog panel for best experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
      ),
    );
  }
}

class _CarouselQuickSend extends StatelessWidget {
  final String contactId;
  const _CarouselQuickSend({required this.contactId});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'For product carousels with multiple cards, use the full Catalog panel for best experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
        ),
      ),
    );
  }
}
