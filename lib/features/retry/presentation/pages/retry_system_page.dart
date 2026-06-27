import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/retry_config_section.dart';
import 'package:iFloraBuzz/features/settings/presentation/widgets/retry_health_section.dart';

/// Full-page view for the Retry System.
/// Left panel: Phase Configuration. Right panel: System Health & Logs.
class RetrySystemPage extends StatelessWidget {
  const RetrySystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.replay_circle_filled_outlined,
                      color: AppTheme.secondaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Retry System',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                    ),
                    const Text(
                      'Configure retry phases and monitor system health',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Two-column layout ────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                // Side-by-side on wide screens, stacked on narrow
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Phase Configuration
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Phase Configuration',
                                Icons.tune_rounded, AppTheme.primaryColor),
                            const SizedBox(height: 12),
                            const RetryConfigSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right: System Health
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('System Health & Logs',
                                Icons.monitor_heart_outlined, Colors.deepPurple),
                            const SizedBox(height: 12),
                            const RetryHealthSection(),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                // Stacked layout for narrow screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Phase Configuration',
                        Icons.tune_rounded, AppTheme.primaryColor),
                    const SizedBox(height: 12),
                    const RetryConfigSection(),
                    const SizedBox(height: 24),
                    _sectionLabel('System Health & Logs',
                        Icons.monitor_heart_outlined, Colors.deepPurple),
                    const SizedBox(height: 12),
                    const RetryHealthSection(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
