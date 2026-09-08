import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/core/di/injection.dart';

/// Full-screen form to create or edit a catalog product
class ProductFormPage extends StatefulWidget {
  final String catalogId;
  final ProductModel? existingProduct;

  const ProductFormPage({super.key, required this.catalogId, this.existingProduct});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _skuController = TextEditingController();
  final _linkController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _currency = 'INR';
  String _availability = 'in stock';
  String _condition = 'new';
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String? _uploadedImageUrl;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD'];
  final List<String> _availabilities = ['in stock', 'out of stock', 'preorder', 'available for order', 'discontinued'];
  final List<String> _conditions = ['new', 'used', 'refurbished'];

  bool get _isEdit => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _populateForm(widget.existingProduct!);
  }

  void _populateForm(ProductModel p) {
    _nameController.text = p.name;
    _descController.text = p.description;
    _priceController.text = p.price.toString();
    if (p.salePrice != null) _salePriceController.text = p.salePrice.toString();
    _skuController.text = p.retailerId;
    _linkController.text = p.link;
    _brandController.text = p.brand;
    _categoryController.text = p.category;
    _imageUrlController.text = p.imageUrl;
    _currency = p.currency;
    _availability = p.availability;
    _condition = p.condition;
    _uploadedImageUrl = p.imageUrl.isNotEmpty ? p.imageUrl : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _skuController.dispose();
    _linkController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogOperationSuccess) {
          setState(() => _isSaving = false);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        }
        if (state is CatalogError) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_isEdit ? 'Edit Product' : 'Add Product',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'Update' : 'Add Product',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: image + basic info
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildImageSection(),
                const SizedBox(height: 24),
                _buildCard('Basic Information', [
                  _formField('Product Name *', _nameController, 'e.g. Wireless Earphones', required: true),
                  _formField('Description', _descController, 'Describe the product...', maxLines: 3),
                  _formField('Retailer ID (SKU) *', _skuController, 'e.g. WE-BLK-001', required: true),
                ]),
              ],
            ),
          ),
        ),
        // Right: pricing + meta
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
            child: Column(
              children: [
                _buildCard('Pricing', [_buildPricingRow()]),
                const SizedBox(height: 16),
                _buildCard('Product Details', [
                  _buildDropdownRow(),
                  _formField('Product URL', _linkController, 'https://yourstore.com/product'),
                  _formField('Brand', _brandController, 'Brand name'),
                  _formField('Category', _categoryController, 'Electronics, Clothing...'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildImageSection(),
          const SizedBox(height: 16),
          _buildCard('Basic Information', [
            _formField('Product Name *', _nameController, 'e.g. Wireless Earphones', required: true),
            _formField('Description', _descController, 'Describe the product...', maxLines: 3),
            _formField('Retailer ID (SKU) *', _skuController, 'e.g. WE-BLK-001', required: true),
          ]),
          const SizedBox(height: 16),
          _buildCard('Pricing', [_buildPricingRow()]),
          const SizedBox(height: 16),
          _buildCard('Product Details', [
            _buildDropdownRow(),
            _formField('Product URL', _linkController, 'https://yourstore.com/product'),
            _formField('Brand', _brandController, 'Brand name'),
            _formField('Category', _categoryController, 'Electronics, Clothing...'),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final imageUrl = _uploadedImageUrl ?? _imageUrlController.text.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Image', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholderBox())
                : _imagePlaceholderBox(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  icon: _isUploadingImage
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded, size: 16),
                  label: Text(_isUploadingImage ? 'Uploading...' : 'Upload Image',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Or paste image URL:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _imageUrlController,
            decoration: _inputDecoration('https://...', Icons.link_rounded),
            onChanged: (v) => setState(() => _uploadedImageUrl = v.isNotEmpty ? v : null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPricingRow() {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<String>(
                value: _currency,
                decoration: _inputDecoration('', Icons.attach_money_rounded),
                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'INR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Price *', Icons.currency_rupee_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Price is required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _salePriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('Sale Price (optional)', Icons.local_offer_rounded),
        ),
      ],
    );
  }

  Widget _buildDropdownRow() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _availability,
          decoration: _inputDecoration('Availability', Icons.inventory_rounded),
          items: _availabilities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _availability = v ?? 'in stock'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _condition,
          decoration: _inputDecoration('Condition', Icons.star_outline_rounded),
          items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _condition = v ?? 'new'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _formField(String label, TextEditingController controller, String hint,
      {int maxLines = 1, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: _inputDecoration(hint, null),
            validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null : null,
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholderBox() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('No image', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey.shade400) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      );

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final catalogRepo = getIt<CatalogRepository>();
      String imageUrl;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        imageUrl = await catalogRepo.uploadProductImage(
          imageBytes: Uint8List.fromList(bytes),
          fileName: picked.name,
          mimeType: picked.mimeType ?? 'image/jpeg',
        );
      } else {
        imageUrl = await catalogRepo.uploadProductImage(
          imagePath: picked.path,
          fileName: picked.name,
          mimeType: picked.mimeType ?? 'image/jpeg',
        );
      }

      setState(() {
        _uploadedImageUrl = imageUrl;
        _imageUrlController.text = imageUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final imageUrl = _uploadedImageUrl ?? _imageUrlController.text.trim();
    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product image is required'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    if (_isEdit && widget.existingProduct?.id != null) {
      context.read<CatalogBloc>().add(UpdateProduct(
        productId: widget.existingProduct!.id!,
        updates: {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'price': double.tryParse(_priceController.text.trim()) ?? 0,
          'currency': _currency,
          'imageUrl': imageUrl,
          'availability': _availability,
          'condition': _condition,
          'link': _linkController.text.trim(),
          'brand': _brandController.text.trim(),
          'category': _categoryController.text.trim(),
          if (_salePriceController.text.trim().isNotEmpty)
            'salePrice': double.tryParse(_salePriceController.text.trim()),
        },
      ));
    } else {
      context.read<CatalogBloc>().add(CreateProduct(
        catalogId: widget.catalogId,
        retailerId: _skuController.text.trim(),
        name: _nameController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        imageUrl: imageUrl,
        description: _descController.text.trim(),
        currency: _currency,
        availability: _availability,
        condition: _condition,
        link: _linkController.text.trim(),
        brand: _brandController.text.trim(),
        category: _categoryController.text.trim(),
        salePrice: _salePriceController.text.trim().isNotEmpty
            ? double.tryParse(_salePriceController.text.trim())
            : null,
      ));
    }
  }
}
