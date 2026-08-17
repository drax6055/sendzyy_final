import 'dart:async';
import 'package:iFloraBuzz/core/js/razorpay_interop.dart';
import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/di/injection.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';
import 'package:iFloraBuzz/features/auth/presentation/pages/login_page.dart';
import 'package:iFloraBuzz/features/credits/data/models/panel_plan.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:dio/dio.dart';

class PackageSelectionPage extends StatefulWidget {
  final String? regToken;
  final String? renewEmail;
  final String? renewPassword;

  const PackageSelectionPage({super.key, this.regToken, this.renewEmail, this.renewPassword});

  @override
  State<PackageSelectionPage> createState() => _PackageSelectionPageState();
}

class _PackageSelectionPageState extends State<PackageSelectionPage> {
  List<PanelPlan> _plans = [];
  PanelPlan? _selectedPlan;
  bool _isLoading = true;
  bool _isPaying = false;
  String? _razorpayKey;

  Completer<Map<String, String>?>? _paymentCompleter;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final repo = getIt<WhatsAppRepository>();
      final dio = getIt<Dio>();
      final plans = await repo.fetchPanelPlans();
      String? key;
      try {
        final cfg = await dio.get('/config');
        key = cfg.data['razorpayKeyId'];
      } catch (_) {}
      setState(() {
        _plans = plans;
        // Default select the last plan (12 months)
        _selectedPlan = plans.isNotEmpty ? plans.last : null;
        _razorpayKey = key;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _selectPlan(PanelPlan plan) {
    setState(() => _selectedPlan = plan);
  }

  void _proceedToPayment() async {
    if (_selectedPlan == null) return;
    setState(() => _isPaying = true);

    final dio = getIt<Dio>();
    final plan = _selectedPlan!;
    final isNewRegistration = widget.regToken != null;
    final isRenewal = widget.renewEmail != null && widget.renewPassword != null;

    if (_razorpayKey != null && _razorpayKey!.isNotEmpty) {
      try {
        final Map<String, dynamic> orderData;
        if (isNewRegistration) {
          final resp = await dio.post('/create-panel-order-register', data: {
            'regToken': widget.regToken,
            'planId': plan.id,
          });
          orderData = Map<String, dynamic>.from(resp.data);
        } else if (isRenewal) {
          final resp = await dio.post('/create-panel-order-renew', data: {
            'email': widget.renewEmail,
            'password': widget.renewPassword,
            'planId': plan.id,
          });
          orderData = Map<String, dynamic>.from(resp.data);
        } else {
          final repo = getIt<WhatsAppRepository>();
          orderData = await repo.createPanelOrder(planId: plan.id);
        }

        final result = await triggerRazorpayPayment(
          key: _razorpayKey ?? '',
          amount: (orderData['amount'] as num).toInt(),
          currency: orderData['currency'] ?? 'INR',
          name: 'Send-O Panel',
          description: '${plan.name} - ${plan.durationLabel} Access',
          orderId: orderData['id'].toString(),
        );

        if (result == null) {
          if (mounted) setState(() => _isPaying = false);
          return;
        }

        bool success;
        if (isNewRegistration) {
          final resp = await dio.post('/verify-panel-payment-register', data: {
            'regToken': widget.regToken,
            'planId': plan.id,
            'razorpay_order_id': result['orderId'],
            'razorpay_payment_id': result['paymentId'],
            'razorpay_signature': result['signature'],
          });
          success = resp.statusCode == 200;
        } else if (isRenewal) {
          final resp = await dio.post('/verify-panel-payment-renew', data: {
            'email': widget.renewEmail,
            'password': widget.renewPassword,
            'planId': plan.id,
            'razorpay_order_id': result['orderId'],
            'razorpay_payment_id': result['paymentId'],
            'razorpay_signature': result['signature'],
          });
          success = resp.statusCode == 200;
        } else {
          final repo = getIt<WhatsAppRepository>();
          success = await repo.verifyPanelPayment(
            planId: plan.id,
            orderId: result['orderId']!,
            paymentId: result['paymentId']!,
            signature: result['signature']!,
          );
        }

        if (!success) {
          if (mounted) {
            setState(() => _isPaying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment verification failed.')),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isPaying = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment error: $e')),
          );
        }
        return;
      }
    }

    if (mounted) _goToLogin();
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful! Please log in.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.secondaryColor, AppTheme.accentColor],
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : _plans.isEmpty
                  ? const Text('Failed to load plans. Please try again.',
                      style: TextStyle(color: Colors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium, size: 56, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text(
                            'Activate Your Panel',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Choose a plan — pay once, use all the way',
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(height: 32),
                          // Plan selector chips
                          _PlanSelector(
                            plans: _plans,
                            selected: _selectedPlan,
                            onSelect: _selectPlan,
                          ),
                          const SizedBox(height: 24),
                          // Plan detail card
                          if (_selectedPlan != null)
                            _PlanCard(
                              plan: _selectedPlan!,
                              isPaying: _isPaying,
                              onPay: _proceedToPayment,
                            ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

// ── Plan selector row ──────────────────────────────────────────────────────────

class _PlanSelector extends StatelessWidget {
  final List<PanelPlan> plans;
  final PanelPlan? selected;
  final ValueChanged<PanelPlan> onSelect;

  const _PlanSelector({required this.plans, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: plans.map((plan) {
        final isSelected = selected?.id == plan.id;
        return GestureDetector(
          onTap: () => onSelect(plan),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.white54,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plan.durationLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${plan.totalPrice}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppTheme.secondaryColor : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Plan detail card ───────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final PanelPlan plan;
  final bool isPaying;
  final VoidCallback onPay;

  const _PlanCard({required this.plan, required this.isPaying, required this.onPay});

  String _expiryDate() {
    final exp = DateTime.now().add(Duration(days: plan.panelDays));
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${exp.day} ${months[exp.month - 1]} ${exp.year}';
  }

  @override
  Widget build(BuildContext context) {
    final gstAmount = plan.totalPrice - plan.basePrice;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${plan.durationLabel.toUpperCase()} ACCESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plan.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.description,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${plan.totalPrice}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  '/ ${plan.durationLabel.toLowerCase()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // GST breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _PriceRow('Base price', '₹${plan.basePrice}'),
                const SizedBox(height: 4),
                _PriceRow('GST (${plan.gstPercent}%)', '₹$gstAmount'),
                const Divider(height: 12),
                _PriceRow('Total payable', '₹${plan.totalPrice}', bold: true),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Features
          _FeatureRow(Icons.calendar_today_outlined, 'Valid for ${plan.panelDays} days'),
          const SizedBox(height: 10),
          _FeatureRow(Icons.event_available_outlined, 'Expires ${_expiryDate()}', highlight: true),
          const SizedBox(height: 10),
          _FeatureRow(Icons.check_circle_outline, 'Full panel access'),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPaying ? null : onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isPaying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Pay ₹${plan.totalPrice} & Activate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: bold ? Colors.black87 : Colors.grey,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 12, color: bold ? AppTheme.primaryColor : Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _FeatureRow(this.icon, this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: highlight ? Colors.orange : AppTheme.primaryColor),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(
          fontSize: 13,
          color: highlight ? Colors.orange.shade800 : Colors.black87,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        )),
      ],
    );
  }
}
