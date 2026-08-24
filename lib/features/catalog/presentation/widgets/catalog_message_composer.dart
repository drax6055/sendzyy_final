import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';

/// Form to compose and send a Catalog Message.
/// Shows full catalog thumbnail + "View Catalog" button on WhatsApp.
class CatalogMessageComposer extends StatefulWidget {
  /// Pre-fill the recipient phone number (e.g. from chat panel).
  final String? initialTo;
  final String? initialThumbnailId;

  const CatalogMessageComposer({
    super.key,
    this.initialTo,
    this.initialThumbnailId,
  });

  @override
  State<CatalogMessageComposer> createState() => _CatalogMessageComposerState();
}

class _CatalogMessageComposerState extends State<CatalogMessageComposer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _toCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _footerCtrl;
  late final TextEditingController _thumbnailCtrl;

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo ?? '');
    _bodyCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _thumbnailCtrl = TextEditingController(text: widget.initialThumbnailId ?? '');
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    _thumbnailCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CatalogBloc>().add(
          SendCatalogMessageEvent(
            CatalogMessageRequest(
              to: _toCtrl.text.trim(),
              bodyText: _bodyCtrl.text.trim(),
              footerText: _footerCtrl.text.trim().isEmpty
                  ? null
                  : _footerCtrl.text.trim(),
              thumbnailProductRetailerId:
                  _thumbnailCtrl.text.trim().isEmpty
                      ? null
                      : _thumbnailCtrl.text.trim(),
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogSettingsLoaded) {
          if (state.successMessage != null) {
            _bodyCtrl.clear();
            _footerCtrl.clear();
            if (widget.initialTo == null) _toCtrl.clear();
          }
        }
      },
      builder: (context, state) {
        final isSending = state is CatalogSettingsLoaded && state.isSending;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ComposerInfoBanner(
                icon: Icons.storefront_rounded,
                color: AppTheme.primaryColor,
                title: 'Catalog Message',
                description:
                    'Sends a message with a product thumbnail and "View catalog" button. Customers can browse your entire catalog within WhatsApp.',
              ),
              const SizedBox(height: 20),
              _buildField(
                controller: _toCtrl,
                label: 'Recipient Phone Number *',
                hint: 'e.g. +919876543210',
                icon: Icons.phone_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _bodyCtrl,
                label: 'Message Body *',
                hint: 'e.g. Hello! Browse our catalog and find what you need.',
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 3,
                maxLength: 1024,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length > 1024) return 'Max 1024 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _footerCtrl,
                label: 'Footer Text (optional)',
                hint: 'e.g. Best deals on WhatsApp!',
                icon: Icons.notes_rounded,
                maxLength: 60,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _thumbnailCtrl,
                label: 'Thumbnail Product SKU (optional)',
                hint: 'e.g. 2lc20305pt — uses first product if omitted',
                icon: Icons.image_outlined,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : _send,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isSending ? 'Sending...' : 'Send Catalog Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
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

// ── Single Product Composer ────────────────────────────────────────────────────

class SingleProductComposer extends StatefulWidget {
  final String? initialTo;
  final String? initialCatalogId;
  final String? initialProductId;

  const SingleProductComposer({
    super.key,
    this.initialTo,
    this.initialCatalogId,
    this.initialProductId,
  });

  @override
  State<SingleProductComposer> createState() => _SingleProductComposerState();
}

class _SingleProductComposerState extends State<SingleProductComposer> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _toCtrl;
  late final TextEditingController _catalogCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.initialTo ?? '');
    _catalogCtrl = TextEditingController(text: widget.initialCatalogId ?? '');
    _productCtrl = TextEditingController(text: widget.initialProductId ?? '');
    _bodyCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _catalogCtrl.dispose();
    _productCtrl.dispose();
    _bodyCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CatalogBloc>().add(
          SendSingleProductEvent(
            SingleProductRequest(
              to: _toCtrl.text.trim(),
              catalogId: _catalogCtrl.text.trim(),
              productRetailerId: _productCtrl.text.trim(),
              bodyText: _bodyCtrl.text.trim().isEmpty
                  ? null
                  : _bodyCtrl.text.trim(),
              footerText: _footerCtrl.text.trim().isEmpty
                  ? null
                  : _footerCtrl.text.trim(),
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
          _footerCtrl.clear();
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
              _ComposerInfoBanner(
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF06B6D4),
                title: 'Single Product Message',
                description:
                    'Highlights one specific product with its image, price, and description. Customers can view details and add to cart.',
              ),
              const SizedBox(height: 20),
              _buildField(_toCtrl, 'Recipient Phone *', '+919876543210',
                  Icons.phone_rounded, required: true),
              const SizedBox(height: 14),
              _buildField(_catalogCtrl, 'Catalog ID *',
                  'e.g. 1537566713439863', Icons.storage_rounded,
                  required: true),
              const SizedBox(height: 14),
              _buildField(_productCtrl, 'Product SKU / Retailer ID *',
                  'e.g. 2lc20305pt', Icons.qr_code_rounded,
                  required: true),
              const SizedBox(height: 14),
              _buildField(_bodyCtrl, 'Body Text (optional)',
                  'e.g. Check out this amazing product!',
                  Icons.chat_bubble_outline_rounded, maxLines: 3),
              const SizedBox(height: 14),
              _buildField(_footerCtrl, 'Footer Text (optional)',
                  'e.g. Limited time offer', Icons.notes_rounded,
                  maxLength: 60),
              const SizedBox(height: 24),
              _SendButton(isSending: isSending, onTap: _send, label: 'Send Single Product'),
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

// ── Shared Helpers ────────────────────────────────────────────────────────────

class _ComposerInfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _ComposerInfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
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
