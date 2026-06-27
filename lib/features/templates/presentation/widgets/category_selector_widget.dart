import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

class CategorySelectorWidget extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onChanged;

  const CategorySelectorWidget({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
  });

  static const _categories = [
    _CategoryOption(
      value: 'MARKETING',
      label: 'Marketing',
      description: 'Promotions and offers',
      icon: Icons.campaign_outlined,
    ),
    _CategoryOption(
      value: 'UTILITY',
      label: 'Utility',
      description: 'Transactional updates',
      icon: Icons.receipt_long_outlined,
    ),
    _CategoryOption(
      value: 'AUTHENTICATION',
      label: 'Authentication',
      description: 'OTP and verification codes',
      icon: Icons.lock_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _categories
          .map((option) => _CategoryCard(
                option: option,
                isSelected: selectedCategory == option.value,
                onTap: () => onChanged(option.value),
              ))
          .toList(),
    );
  }
}

class _CategoryOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;

  const _CategoryOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class _CategoryCard extends StatelessWidget {
  final _CategoryOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 22,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.secondaryColor
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: option.value,
              groupValue: isSelected ? option.value : null,
              onChanged: (_) => onTap(),
              activeColor: AppTheme.primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
