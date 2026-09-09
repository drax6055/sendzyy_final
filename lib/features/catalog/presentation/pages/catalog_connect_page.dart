import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

/// Step-by-step wizard to connect an existing catalog or create a new one
class CatalogConnectPage extends StatefulWidget {
  const CatalogConnectPage({super.key});

  @override
  State<CatalogConnectPage> createState() => _CatalogConnectPageState();
}

class _CatalogConnectPageState extends State<CatalogConnectPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isCreate = false; // false = connect existing, true = create new

  final _catalogIdController = TextEditingController();
  final _catalogNameController = TextEditingController();
  String _selectedVertical = 'commerce';

  bool _isLoading = false;
  bool _resultIsLinked = false;

  @override
  void dispose() {
    _pageController.dispose();
    _catalogIdController.dispose();
    _catalogNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state is CatalogLoading) setState(() => _isLoading = true);
        if (state is CatalogOperationSuccess) {
          setState(() => _isLoading = false);
          _goToStep(2); // success step
        }
        if (state is CatalogsLoaded) {
          setState(() {
            _isLoading = false;
            _resultIsLinked = state.selectedCatalog?.isLinked ?? state.catalogs.firstOrNull?.isLinked ?? false;
          });
          _goToStep(2);
        }
        if (state is CatalogError) {
          setState(() => _isLoading = false);
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
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Connect Catalog',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        ),
        body: Column(
          children: [
            // Step indicator
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3Success(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                  ),
                  child: Center(
                    child: i < _currentStep
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : Text('${i + 1}',
                            style: GoogleFonts.inter(
                              color: isActive ? Colors.white : Colors.grey.shade500,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: i < _currentStep ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('How would you like to add a catalog?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Connect an existing Meta catalog or create a new one',
              style: GoogleFonts.inter(color: Colors.grey.shade600)),
          const SizedBox(height: 32),

          // Option: Connect existing
          _optionCard(
            selected: !_isCreate,
            icon: Icons.link_rounded,
            color: AppTheme.primaryColor,
            title: 'Connect Existing Catalog',
            subtitle: 'Link a catalog you already created in Meta Commerce Manager',
            onTap: () => setState(() => _isCreate = false),
          ),
          const SizedBox(height: 16),
          // Option: Create new
          _optionCard(
            selected: _isCreate,
            icon: Icons.add_business_rounded,
            color: Colors.deepPurple,
            title: 'Create New Catalog',
            subtitle: 'Create a new catalog directly through the Meta API',
            onTap: () => setState(() => _isCreate = true),
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToStep(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            _isCreate ? 'Create New Catalog' : 'Connect Existing Catalog',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, color: const Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            _isCreate
                ? 'Enter a name for your new catalog'
                : 'Enter the Catalog ID from your Meta Commerce Manager',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          if (!_isCreate) ...[
            _formLabel('Catalog ID'),
            const SizedBox(height: 8),
            TextField(
              controller: _catalogIdController,
              decoration: _inputDecoration('e.g. 123456789012345', Icons.tag_rounded),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Find your Catalog ID in Meta Commerce Manager → Settings → Catalog ID.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _formLabel('Catalog Name (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _catalogNameController,
              decoration: _inputDecoration('Display name for this catalog', Icons.label_outline_rounded),
            ),
          ] else ...[
            _formLabel('Catalog Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _catalogNameController,
              decoration: _inputDecoration('My Product Catalog', Icons.storefront_outlined),
            ),
            const SizedBox(height: 16),
            _formLabel('Catalog Type'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedVertical,
              decoration: _inputDecoration('Select type', Icons.category_outlined),
              items: const [
                DropdownMenuItem(value: 'commerce', child: Text('E-commerce / Retail')),
                DropdownMenuItem(value: 'vehicles', child: Text('Vehicles')),
                DropdownMenuItem(value: 'real_estate', child: Text('Real Estate')),
                DropdownMenuItem(value: 'destinations', child: Text('Destinations / Travel')),
                DropdownMenuItem(value: 'flights', child: Text('Flights')),
                DropdownMenuItem(value: 'hotels', child: Text('Hotels')),
                DropdownMenuItem(value: 'home_listings', child: Text('Home Listings')),
              ],
              onChanged: (v) => setState(() => _selectedVertical = v ?? 'commerce'),
            ),
          ],

          const SizedBox(height: 40),

          Row(
            children: [
              OutlinedButton(
                onPressed: () => _goToStep(0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                child: Text('Back', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isCreate ? 'Create Catalog' : 'Link Catalog',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Success() {
    final isLinked = _resultIsLinked;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLinked
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : [Colors.orange.shade400, Colors.orange.shade700],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLinked ? Icons.check_rounded : Icons.storefront_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isLinked
                  ? (_isCreate ? 'Catalog Created & Linked!' : 'Catalog Connected!')
                  : (_isCreate ? 'Catalog Created Locally' : 'Catalog Saved Locally'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 24, color: const Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 12),
            Text(
              isLinked
                  ? 'Your catalog is linked to your WhatsApp Business Account. You can now send catalog messages to customers.'
                  : 'Your catalog has been saved in Sendzyy. To send catalog messages in WhatsApp, link a catalog ID from Meta Commerce Manager.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey.shade600, height: 1.6),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                label: Text('Go to Products', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _submit() {
    if (_isCreate) {
      final name = _catalogNameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalog name is required')));
        return;
      }
      context.read<CatalogBloc>().add(CreateCatalog(name: name, verticalType: _selectedVertical));
    } else {
      final catalogId = _catalogIdController.text.trim();
      if (catalogId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalog ID is required')));
        return;
      }
      context.read<CatalogBloc>().add(LinkCatalog(
        catalogId: catalogId,
        catalogName: _catalogNameController.text.trim(),
      ));
    }
  }

  Widget _optionCard({
    required bool selected,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          border: Border.all(color: selected ? color : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Radio<bool>(value: selected, groupValue: true, onChanged: (_) => onTap(), activeColor: color),
          ],
        ),
      ),
    );
  }

  Widget _formLabel(String text) => Text(text,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF374151)));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5)),
      );
}
