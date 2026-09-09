import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class CatalogCard extends StatelessWidget {
  final CatalogModel catalog;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onUnlink;
  final VoidCallback? onDelete;

  const CatalogCard({
    super.key,
    required this.catalog,
    required this.isSelected,
    required this.onTap,
    this.onUnlink,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFEEEEEE),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.catalogName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: isSelected ? Colors.white70 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${catalog.productCount} products',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isSelected ? Colors.white70 : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _linkedBadge(isSelected),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (onUnlink != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: isSelected ? Colors.white70 : Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'unlink') onUnlink?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (catalog.isLinked && onUnlink != null)
                      const PopupMenuItem(
                        value: 'unlink',
                        child: Row(children: [
                          Icon(Icons.link_off_rounded, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Unlink from WhatsApp'),
                        ]),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Catalog', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkedBadge(bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: catalog.isLinked
            ? (isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.12))
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            catalog.isLinked ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 10,
            color: catalog.isLinked
                ? (isSelected ? Colors.white : Colors.green.shade700)
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            catalog.isLinked ? 'Linked' : 'Unlinked',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: catalog.isLinked
                  ? (isSelected ? Colors.white : Colors.green.shade700)
                  : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
