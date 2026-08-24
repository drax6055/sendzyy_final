import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

/// Multi-Product Message composer — up to 30 products across 10 sections.
class MultiProductComposer extends StatefulWidget {
  final String? initialTo;
  final String? initialCatalogId;

  const MultiProductComposer({
    super.key,
    this.initialTo,
    this.initialCatalogId,
  });

  @override
  State<MultiProductComposer> createState() => _MultiProductComposerState();
}

class _MultiProductComposerState extends State<MultiProductComposer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _toCtrl;
  late final TextEditingController _catalogCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _footerCtrl;

  final List<_SectionData> _sections = [];

  int get _totalProducts =>
      _sections.fold(0, (sum, s) => sum + s.productIds.length);

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo ?? '');
    _catalogCtrl = TextEditingController(text: widget.initialCatalogId ?? '');
    _headerCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _footerCtrl = TextEditingController();

    // Start with one section
    _sections.add(_SectionData());
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _catalogCtrl.dispose();
    _headerCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    for (final s in _sections) s.dispose();
    super.dispose();
  }

  void _addSection() {
    if (_sections.length >= 10) return;
    setState(() => _sections.add(_SectionData()));
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) return;
    setState(() {
      _sections[index].dispose();
      _sections.removeAt(index);
    });
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    if (_totalProducts == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product SKU to a section.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sections = _sections
        .where((s) => s.productIds.isNotEmpty)
        .map((s) => MultiProductSection(
              title: s.titleCtrl.text.trim(),
              productRetailerIds: s.productIds,
            ))
        .toList();

    context.read<CatalogBloc>().add(
          SendMultiProductEvent(
            MultiProductRequest(
              to: _toCtrl.text.trim(),
              catalogId: _catalogCtrl.text.trim(),
              headerText: _headerCtrl.text.trim(),
              bodyText: _bodyCtrl.text.trim(),
              footerText: _footerCtrl.text.trim().isEmpty
                  ? null
                  : _footerCtrl.text.trim(),
              sections: sections,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded && state.successMessage != null) {
          _headerCtrl.clear();
          _bodyCtrl.clear();
          _footerCtrl.clear();
          setState(() {
            for (final s in _sections) s.dispose();
            _sections.clear();
            _sections.add(_SectionData());
          });
          if (widget.initialTo == null) _toCtrl.clear();
        }
      },
      builder: (context, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(),
              const SizedBox(height: 20),
              _field(_toCtrl, 'Recipient Phone *', '+919876543210',
                  Icons.phone_rounded, required: true),
              const SizedBox(height: 14),
              _field(_catalogCtrl, 'Catalog ID *', 'e.g. 1537566713439863',
                  Icons.storage_rounded, required: true),
              const SizedBox(height: 14),
              _field(_headerCtrl, 'Header Text *', 'e.g. Our Products',
                  Icons.title_rounded, required: true, maxLength: 60),
              const SizedBox(height: 14),
              _field(_bodyCtrl, 'Body Text *',
                  'e.g. Browse our latest collection!',
                  Icons.chat_bubble_outline_rounded,
                  required: true, maxLines: 3, maxLength: 1024),
              const SizedBox(height: 14),
              _field(_footerCtrl, 'Footer Text (optional)',
                  'e.g. Free shipping on orders above ₹500',
                  Icons.notes_rounded, maxLength: 60),
              const SizedBox(height: 24),
              // Sections
              Row(
                children: [
                  const Text(
                    'Product Sections',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1D1E)),
                  ),
                  const Spacer(),
                  Text(
                    '$_totalProducts products / ${_sections.length} sections',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(
                _sections.length,
                (i) => _SectionEditor(
                  key: ValueKey(_sections[i].id),
                  data: _sections[i],
                  index: i,
                  canRemove: _sections.length > 1,
                  onRemove: () => _removeSection(i),
                  onChanged: () => setState(() {}),
                ),
              ),
              if (_sections.length < 10)
                TextButton.icon(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Section'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor),
                ),
              const SizedBox(height: 24),
              _SendButton(isSending: isSending, onTap: _send, label: 'Send Multi-Product'),
            ],
          ),
        );
      },
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.grid_view_rounded, color: Color(0xFF6366F1), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Multi-Product Message — Up to 30 products in 10 sections. Customers can browse, add to cart, and place orders directly in WhatsApp.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionData {
  static int _counter = 0;
  final int id;
  final TextEditingController titleCtrl;
  final List<TextEditingController> productControllers;

  _SectionData()
      : id = _counter++,
        titleCtrl = TextEditingController(),
        productControllers = [TextEditingController()];

  List<String> get productIds => productControllers
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void dispose() {
    titleCtrl.dispose();
    for (final c in productControllers) c.dispose();
  }
}

class _SectionEditor extends StatefulWidget {
  final _SectionData data;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SectionEditor({
    super.key,
    required this.data,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  void _addProduct() {
    if (widget.data.productControllers.length >= 30) return;
    setState(() {
      widget.data.productControllers.add(TextEditingController());
    });
    widget.onChanged();
  }

  void _removeProduct(int idx) {
    if (widget.data.productControllers.length <= 1) return;
    setState(() {
      widget.data.productControllers[idx].dispose();
      widget.data.productControllers.removeAt(idx);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Section ${widget.index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove section',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.data.titleCtrl,
              maxLength: 24,
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: 'Section Title',
                hintText: 'e.g. Popular Bundles',
                prefixIcon: const Icon(Icons.label_outline, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Product SKUs',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              widget.data.productControllers.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: widget.data.productControllers[i],
                        onChanged: (_) => widget.onChanged(),
                        decoration: InputDecoration(
                          hintText: 'Product SKU / Retailer ID',
                          prefixIcon:
                              const Icon(Icons.qr_code_rounded, size: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    if (widget.data.productControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18,
                            color: Colors.grey),
                        onPressed: () => _removeProduct(i),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.data.productControllers.length < 30)
              TextButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Product'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Product Carousel Composer ─────────────────────────────────────────────────

class ProductCarouselComposer extends StatefulWidget {
  final String? initialTo;
  final String? initialCatalogId;

  const ProductCarouselComposer({
    super.key,
    this.initialTo,
    this.initialCatalogId,
  });

  @override
  State<ProductCarouselComposer> createState() =>
      _ProductCarouselComposerState();
}

class _ProductCarouselComposerState extends State<ProductCarouselComposer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _toCtrl;
  late final TextEditingController _catalogCtrl;
  late final TextEditingController _bodyCtrl;

  final List<TextEditingController> _cardControllers = [];

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo ?? '');
    _catalogCtrl = TextEditingController(text: widget.initialCatalogId ?? '');
    _bodyCtrl = TextEditingController();
    // Minimum 2 cards
    _cardControllers.add(TextEditingController());
    _cardControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _catalogCtrl.dispose();
    _bodyCtrl.dispose();
    for (final c in _cardControllers) c.dispose();
    super.dispose();
  }

  void _addCard() {
    if (_cardControllers.length >= 10) return;
    setState(() => _cardControllers.add(TextEditingController()));
  }

  void _removeCard(int i) {
    if (_cardControllers.length <= 2) return;
    setState(() {
      _cardControllers[i].dispose();
      _cardControllers.removeAt(i);
    });
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;

    final catalogId = _catalogCtrl.text.trim();
    final cards = _cardControllers
        .asMap()
        .entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .map((e) => ProductCarouselCard(
              cardIndex: e.key,
              productRetailerId: e.value.text.trim(),
              catalogId: catalogId,
            ))
        .toList();

    if (cards.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A carousel requires at least 2 product cards.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.read<CatalogBloc>().add(
          SendProductCarouselEvent(
            ProductCarouselRequest(
              to: _toCtrl.text.trim(),
              bodyText: _bodyCtrl.text.trim(),
              cards: cards,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded && state.successMessage != null) {
          _bodyCtrl.clear();
          for (final c in _cardControllers) c.clear();
          if (widget.initialTo == null) _toCtrl.clear();
        }
      },
      builder: (context, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF6D28D9).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.view_carousel_rounded,
                        color: Color(0xFF7C3AED), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Product Carousel — 2 to 10 horizontally scrollable product cards. Each card shows a product from your catalog with a View button.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildField(_toCtrl, 'Recipient Phone *', '+919876543210',
                  Icons.phone_rounded, required: true),
              const SizedBox(height: 14),
              _buildField(_catalogCtrl, 'Catalog ID *',
                  'e.g. 1537566713439863', Icons.storage_rounded,
                  required: true),
              const SizedBox(height: 14),
              _buildField(_bodyCtrl, 'Carousel Body Text *',
                  'e.g. Check out our featured products!',
                  Icons.chat_bubble_outline_rounded,
                  required: true, maxLines: 3, maxLength: 1024),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Product Cards',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1D1E)),
                  ),
                  const Spacer(),
                  Text(
                    '${_cardControllers.length} / 10 cards (min 2)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(
                _cardControllers.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _cardControllers[i],
                          validator: i < 2
                              ? (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required (min 2 cards)'
                                  : null
                              : null,
                          decoration: InputDecoration(
                            hintText: 'Product SKU / Retailer ID',
                            prefixIcon:
                                const Icon(Icons.qr_code_rounded, size: 16),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      if (_cardControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18,
                              color: Colors.grey),
                          onPressed: () => _removeCard(i),
                        ),
                    ],
                  ),
                ),
              ),
              if (_cardControllers.length < 10)
                TextButton.icon(
                  onPressed: _addCard,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Card'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6D28D9)),
                ),
              const SizedBox(height: 24),
              _SendButton(
                  isSending: isSending,
                  onTap: _send,
                  label: 'Send Product Carousel'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onTap;
  final String label;

  const _SendButton({
    required this.isSending,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isSending ? null : onTap,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(isSending ? 'Sending...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
