import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/commerce_settings_card.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/product_browser_widget.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/catalog_message_composer.dart';
import 'package:iFloraBuzz/features/catalog/presentation/widgets/multi_product_composer.dart';

import 'package:iFloraBuzz/core/utils/responsive_helper.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<CatalogBloc>().add(LoadCommerceSettings());
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
        if (state is CatalogSettingsLoaded) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.successMessage!)),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<CatalogBloc>().add(ClearCatalogStatus());
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.errorMessage!)),
                  ],
                ),
                backgroundColor: Colors.red.shade500,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            context.read<CatalogBloc>().add(ClearCatalogStatus());
          }
        }
      },
      child: Column(
        children: [
          // ── Page Header ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              isMobile ? 14 : 20,
              isMobile ? 16 : 24,
              0,
            ),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WhatsApp Catalog',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1D1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Manage your products and send catalog messages',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 20),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 2.5,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
                  unselectedLabelStyle: TextStyle(fontSize: isMobile ? 12 : 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.settings_rounded, size: 18),
                      text: 'Overview',
                    ),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'Products',
                    ),
                    Tab(
                      icon: Icon(Icons.send_rounded, size: 18),
                      text: 'Send Messages',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Tab Views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(),
                _ProductsTab(),
                _SendMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab: Overview ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state is CatalogSettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CatalogError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade400, size: 48),
                const SizedBox(height: 16),
                Text(state.message,
                    style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<CatalogBloc>().add(LoadCommerceSettings()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              if (state is CatalogSettingsLoaded)
                _StatsRow(state: state),
              SizedBox(height: isMobile ? 16 : 24),
              // Commerce settings
              const CommerceSettingsCard(),
              SizedBox(height: isMobile ? 16 : 24),
              // Info card
              _HelpCard(),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final CatalogSettingsLoaded state;

  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    final cards = [
      _StatCard(
        icon: Icons.inventory_2_rounded,
        label: 'Products',
        value: state.isLoadingProducts ? '...' : '${state.products.length}',
        color: const Color(0xFF06B6D4),
      ),
      _StatCard(
        icon: Icons.shopping_cart_checkout_rounded,
        label: 'Cart',
        value: state.settings.isCartEnabled ? 'Enabled' : 'Disabled',
        color: state.settings.isCartEnabled
            ? const Color(0xFF10B981)
            : Colors.grey,
      ),
      _StatCard(
        icon: Icons.visibility_rounded,
        label: 'Catalog',
        value: state.settings.isCatalogVisible ? 'Visible' : 'Hidden',
        color: state.settings.isCatalogVisible
            ? AppTheme.primaryColor
            : Colors.grey,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: c,
                ))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                ),
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'How Catalog Commerce Works',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            '1. Upload inventory to Meta via Commerce Manager',
            '2. Connect your catalog to your WABA',
            '3. Configure cart and catalog visibility above',
            '4. Use the "Send Messages" tab to share products',
            '5. Receive order webhooks when customers check out',
          ].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Tab: Products ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: const ProductBrowserWidget(),
    );
  }
}

// ── Tab: Send Messages ────────────────────────────────────────────────────────

class _SendMessagesTab extends StatefulWidget {
  @override
  State<_SendMessagesTab> createState() => _SendMessagesTabState();
}

class _SendMessagesTabState extends State<_SendMessagesTab> {
  int _selectedComposer = 0;

  final _composerLabels = [
    (icon: Icons.storefront_rounded, label: 'Catalog Msg', color: const Color(0xFF25D366)),
    (icon: Icons.inventory_2_outlined, label: 'Single Product', color: const Color(0xFF06B6D4)),
    (icon: Icons.grid_view_rounded, label: 'Multi-Product', color: const Color(0xFF6366F1)),
    (icon: Icons.view_carousel_rounded, label: 'Carousel', color: const Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      return Column(
        children: [
          // Top horizontal selector on mobile
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _composerLabels.length,
                  (i) {
                    final item = _composerLabels[i];
                    final isSelected = _selectedComposer == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedComposer = i),
                        avatar: Icon(item.icon,
                            size: 16,
                            color: isSelected ? Colors.white : item.color),
                        label: Text(item.label),
                        selectedColor: item.color,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildComposer(),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Left: composer type selector on desktop/tablet
        Container(
          width: 200,
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12, top: 8),
                child: Text(
                  'Message Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ...List.generate(
                _composerLabels.length,
                (i) {
                  final item = _composerLabels[i];
                  final isSelected = _selectedComposer == i;
                  return InkWell(
                    onTap: () => setState(() => _selectedComposer = i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: item.color.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon,
                              color: isSelected
                                  ? item.color
                                  : Colors.grey.shade400,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? item.color
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        // Right: composer form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildComposer(),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    switch (_selectedComposer) {
      case 0:
        return const CatalogMessageComposer();
      case 1:
        return const SingleProductComposer();
      case 2:
        return const MultiProductComposer();
      case 3:
        return const ProductCarouselComposer();
      default:
        return const SizedBox.shrink();
    }
  }
}
