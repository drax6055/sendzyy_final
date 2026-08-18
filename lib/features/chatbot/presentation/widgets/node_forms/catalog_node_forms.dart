import 'package:flutter/material.dart';
import 'package:iFloraBuzz/features/chatbot/data/models/flow_graph.dart';

/// Properties panel form for a Catalog Message node.
class CatalogMessageNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const CatalogMessageNodeForm({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<CatalogMessageNodeForm> createState() => _CatalogMessageNodeFormState();
}

class _CatalogMessageNodeFormState extends State<CatalogMessageNodeForm> {
  late TextEditingController _bodyCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _thumbnailCtrl;

  @override
  void initState() {
    super.initState();
    _bodyCtrl = TextEditingController(text: widget.node.data['body'] ?? '');
    _footerCtrl = TextEditingController(text: widget.node.data['footer'] ?? '');
    _thumbnailCtrl = TextEditingController(
        text: widget.node.data['thumbnailProductRetailerId'] ?? '');
  }

  @override
  void didUpdateWidget(CatalogMessageNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _bodyCtrl.text = widget.node.data['body'] ?? '';
      _footerCtrl.text = widget.node.data['footer'] ?? '';
      _thumbnailCtrl.text =
          widget.node.data['thumbnailProductRetailerId'] ?? '';
    }
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    _thumbnailCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      'body': _bodyCtrl.text,
      'footer': _footerCtrl.text,
      'thumbnailProductRetailerId': _thumbnailCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeTypeHeader(
          icon: Icons.storefront_rounded,
          label: 'Catalog Message',
          color: const Color(0xFF25D366),
          description: 'Sends the full catalog with a "View Catalog" button.',
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _bodyCtrl,
          label: 'Body Text *',
          hint: 'e.g. Browse our catalog!',
          maxLines: 3,
          maxLength: 1024,
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _footerCtrl,
          label: 'Footer (optional)',
          hint: 'e.g. Best deals on WhatsApp!',
          maxLength: 60,
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _thumbnailCtrl,
          label: 'Thumbnail Product SKU (optional)',
          hint: 'e.g. 2lc20305pt',
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

/// Properties panel form for a Single Product node.
class SingleProductNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const SingleProductNodeForm({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<SingleProductNodeForm> createState() => _SingleProductNodeFormState();
}

class _SingleProductNodeFormState extends State<SingleProductNodeForm> {
  late TextEditingController _catalogCtrl;
  late TextEditingController _productCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _catalogCtrl =
        TextEditingController(text: widget.node.data['catalogId'] ?? '');
    _productCtrl =
        TextEditingController(text: widget.node.data['productRetailerId'] ?? '');
    _bodyCtrl = TextEditingController(text: widget.node.data['body'] ?? '');
    _footerCtrl = TextEditingController(text: widget.node.data['footer'] ?? '');
  }

  @override
  void didUpdateWidget(SingleProductNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _catalogCtrl.text = widget.node.data['catalogId'] ?? '';
      _productCtrl.text = widget.node.data['productRetailerId'] ?? '';
      _bodyCtrl.text = widget.node.data['body'] ?? '';
      _footerCtrl.text = widget.node.data['footer'] ?? '';
    }
  }

  @override
  void dispose() {
    _catalogCtrl.dispose();
    _productCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      'catalogId': _catalogCtrl.text,
      'productRetailerId': _productCtrl.text,
      'body': _bodyCtrl.text,
      'footer': _footerCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeTypeHeader(
          icon: Icons.inventory_2_outlined,
          label: 'Single Product',
          color: const Color(0xFF06B6D4),
          description: 'Highlights one product with image, price, and "Add to cart".',
        ),
        const SizedBox(height: 16),
        _field(_catalogCtrl, 'Catalog ID *', 'e.g. 1537566713439863'),
        const SizedBox(height: 12),
        _field(_productCtrl, 'Product Retailer ID *', 'e.g. 2lc20305pt'),
        const SizedBox(height: 12),
        _field(_bodyCtrl, 'Body Text (optional)', 'e.g. Check this out!',
            maxLines: 2),
        const SizedBox(height: 12),
        _field(_footerCtrl, 'Footer (optional)', 'e.g. Limited stock',
            maxLength: 60),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: (_) => _emit(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

/// Properties panel form for a Multi-Product node.
class MultiProductNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const MultiProductNodeForm({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<MultiProductNodeForm> createState() => _MultiProductNodeFormState();
}

class _MultiProductNodeFormState extends State<MultiProductNodeForm> {
  late TextEditingController _catalogCtrl;
  late TextEditingController _headerCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _footerCtrl;
  final List<_SectionEntry> _sections = [];

  @override
  void initState() {
    super.initState();
    _catalogCtrl =
        TextEditingController(text: widget.node.data['catalogId'] ?? '');
    _headerCtrl =
        TextEditingController(text: widget.node.data['headerText'] ?? '');
    _bodyCtrl = TextEditingController(text: widget.node.data['body'] ?? '');
    _footerCtrl = TextEditingController(text: widget.node.data['footer'] ?? '');
    _loadSections();
  }

  void _loadSections() {
    final raw = widget.node.data['sections'] as List? ?? [];
    _sections.clear();
    for (final s in raw) {
      final sMap = s as Map;
      final items = (sMap['productItems'] as List? ?? [])
          .map((i) => (i as Map)['productRetailerId']?.toString() ?? '')
          .toList();
      _sections.add(_SectionEntry(
        titleCtrl: TextEditingController(text: sMap['title']?.toString() ?? ''),
        productIds: List<String>.from(items),
      ));
    }
    if (_sections.isEmpty) _sections.add(_SectionEntry());
  }

  @override
  void didUpdateWidget(MultiProductNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _catalogCtrl.text = widget.node.data['catalogId'] ?? '';
      _headerCtrl.text = widget.node.data['headerText'] ?? '';
      _bodyCtrl.text = widget.node.data['body'] ?? '';
      _footerCtrl.text = widget.node.data['footer'] ?? '';
      for (final s in _sections) {
        s.titleCtrl.dispose();
      }
      _loadSections();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _catalogCtrl.dispose();
    _headerCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    for (final s in _sections) s.titleCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      'catalogId': _catalogCtrl.text,
      'headerText': _headerCtrl.text,
      'body': _bodyCtrl.text,
      'footer': _footerCtrl.text,
      'sections': _sections
          .map((s) => {
                'title': s.titleCtrl.text,
                'productItems': s.productIds
                    .map((id) => {'productRetailerId': id})
                    .toList(),
              })
          .toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeTypeHeader(
          icon: Icons.grid_view_rounded,
          label: 'Multi-Product',
          color: const Color(0xFF6366F1),
          description: 'Up to 30 products in 10 sections with cart support.',
        ),
        const SizedBox(height: 16),
        _field(_catalogCtrl, 'Catalog ID *', 'e.g. 1537566713439863'),
        const SizedBox(height: 10),
        _field(_headerCtrl, 'Header *', 'e.g. Our Products'),
        const SizedBox(height: 10),
        _field(_bodyCtrl, 'Body *', 'e.g. Browse and shop!', maxLines: 2),
        const SizedBox(height: 10),
        _field(_footerCtrl, 'Footer (optional)', 'e.g. Free shipping',
            maxLength: 60),
        const SizedBox(height: 16),
        const Text('Sections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        ...List.generate(_sections.length, (i) {
          final s = _sections[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Section ${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const Spacer(),
                      if (_sections.length > 1)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _sections[i].titleCtrl.dispose();
                              _sections.removeAt(i);
                            });
                            _emit();
                          },
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: s.titleCtrl,
                    onChanged: (_) => _emit(),
                    decoration: const InputDecoration(
                      hintText: 'Section title',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...s.productIds.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: e.value,
                              onChanged: (v) {
                                s.productIds[e.key] = v;
                                _emit();
                              },
                              decoration: const InputDecoration(
                                hintText: 'Product SKU',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ),
                          if (s.productIds.length > 1)
                            GestureDetector(
                              onTap: () {
                                setState(() => s.productIds.removeAt(e.key));
                                _emit();
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.close, size: 14, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => s.productIds.add(''));
                      _emit();
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add SKU', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_sections.length < 10)
          TextButton.icon(
            onPressed: () {
              setState(() => _sections.add(_SectionEntry()));
              _emit();
            },
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add Section'),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: (_) => _emit(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _SectionEntry {
  final TextEditingController titleCtrl;
  final List<String> productIds;

  _SectionEntry({TextEditingController? titleCtrl, List<String>? productIds})
      : titleCtrl = titleCtrl ?? TextEditingController(),
        productIds = productIds ?? [''];
}

/// Properties panel form for a Product Carousel node.
class ProductCarouselNodeForm extends StatefulWidget {
  final FlowNode node;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const ProductCarouselNodeForm({
    super.key,
    required this.node,
    required this.onChanged,
  });

  @override
  State<ProductCarouselNodeForm> createState() =>
      _ProductCarouselNodeFormState();
}

class _ProductCarouselNodeFormState extends State<ProductCarouselNodeForm> {
  late TextEditingController _catalogCtrl;
  late TextEditingController _bodyCtrl;
  List<String> _cards = [];

  @override
  void initState() {
    super.initState();
    _catalogCtrl =
        TextEditingController(text: widget.node.data['catalogId'] ?? '');
    _bodyCtrl = TextEditingController(text: widget.node.data['body'] ?? '');
    _loadCards();
  }

  void _loadCards() {
    final rawCards = widget.node.data['cards'] as List? ?? [];
    _cards = rawCards
        .map((c) => (c as Map)['productRetailerId']?.toString() ?? '')
        .toList();
    if (_cards.length < 2) {
      while (_cards.length < 2) _cards.add('');
    }
  }

  @override
  void didUpdateWidget(ProductCarouselNodeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _catalogCtrl.text = widget.node.data['catalogId'] ?? '';
      _bodyCtrl.text = widget.node.data['body'] ?? '';
      _loadCards();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _catalogCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      'catalogId': _catalogCtrl.text,
      'body': _bodyCtrl.text,
      'cards': _cards
          .asMap()
          .entries
          .map((e) => {
                'cardIndex': e.key,
                'productRetailerId': e.value,
                'catalogId': _catalogCtrl.text,
              })
          .toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeTypeHeader(
          icon: Icons.view_carousel_rounded,
          label: 'Product Carousel',
          color: const Color(0xFF7C3AED),
          description: '2–10 horizontal product cards, each "Add to cart" ready.',
        ),
        const SizedBox(height: 16),
        _field(_catalogCtrl, 'Catalog ID *', 'e.g. 1537566713439863'),
        const SizedBox(height: 10),
        _field(_bodyCtrl, 'Body *', 'e.g. Featured products!', maxLines: 2, maxLength: 1024),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Cards',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Text('${_cards.length}/10',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        ..._cards.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE9FE),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value,
                      onChanged: (v) {
                        _cards[e.key] = v;
                        _emit();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Product SKU / Retailer ID',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  if (_cards.length > 2)
                    GestureDetector(
                      onTap: () {
                        setState(() => _cards.removeAt(e.key));
                        _emit();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            )),
        if (_cards.length < 10)
          TextButton.icon(
            onPressed: () {
              setState(() => _cards.add(''));
              _emit();
            },
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Add Card'),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: (_) => _emit(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ── Shared header widget ──────────────────────────────────────────────────────

class _NodeTypeHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String description;

  const _NodeTypeHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
