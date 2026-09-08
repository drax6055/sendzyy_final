import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_order_model.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class OrderCard extends StatelessWidget {
  final CatalogOrderModel order;
  final VoidCallback? onTap;
  final void Function(String status)? onStatusChange;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: order.isNew
              ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.6), width: 1.5)
              : Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: order.isNew
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: order.isNew ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Phone / Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (order.isNew)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                order.customerName.isNotEmpty ? order.customerName : order.customerPhone,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: const Color(0xFF1A1A2E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (order.customerName.isNotEmpty)
                          Text(
                            order.customerPhone,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ),
                  // Status badge + amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(order.status),
                      const SizedBox(height: 4),
                      Text(
                        order.formattedTotal,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Product chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: order.productItems.take(4).map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.productName.isNotEmpty ? item.productName : item.productRetailerId} ×${item.quantity}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList()
                  ..addAll(order.productItems.length > 4
                      ? [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${order.productItems.length - 4} more',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                            ),
                          )
                        ]
                      : []),
              ),
              const SizedBox(height: 10),
              // Footer: time + actions
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    order.createdAt != null
                        ? DateFormat('dd MMM, hh:mm a').format(order.createdAt!.toLocal())
                        : '',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  const Spacer(),
                  if (onStatusChange != null) _quickStatusMenu(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    const colors = {
      'new': Color(0xFF1E88E5),
      'viewed': Color(0xFF9C27B0),
      'fulfilled': Color(0xFF43A047),
      'cancelled': Color(0xFFE53935),
    };
    final color = colors[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _quickStatusMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (status) => onStatusChange?.call(status),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'viewed', child: Text('Mark as Viewed')),
        PopupMenuItem(value: 'fulfilled', child: Text('Mark as Fulfilled')),
        PopupMenuItem(value: 'cancelled', child: Text('Cancel Order')),
      ],
    );
  }
}
