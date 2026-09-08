import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iFloraBuzz/features/catalog/data/models/product_model.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSend;

  const ProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onDelete,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                // Availability badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: _availabilityBadge(),
                ),
                // Sync badge
                if (product.isSynced)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 12),
                    ),
                  ),
                // Price chip overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                    child: Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (product.salePrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${product.currency} ${product.price.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Product info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${product.retailerId}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                if (onSend != null)
                  _actionBtn(Icons.send_rounded, AppTheme.primaryColor, onSend!),
                const Spacer(),
                if (onEdit != null)
                  _actionBtn(Icons.edit_outlined, Colors.blue.shade600, onEdit!),
                const SizedBox(width: 4),
                if (onDelete != null)
                  _actionBtn(Icons.delete_outline_rounded, Colors.red.shade500, onDelete!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withValues(alpha: 0.08), AppTheme.primaryColor.withValues(alpha: 0.15)],
        ),
      ),
      child: Icon(Icons.image_not_supported_outlined, color: AppTheme.primaryColor.withValues(alpha: 0.4), size: 36),
    );
  }

  Widget _availabilityBadge() {
    final isInStock = product.availability == 'in stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isInStock ? Colors.green.shade700 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isInStock ? 'In Stock' : product.availability,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
