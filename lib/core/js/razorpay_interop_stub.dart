import 'package:flutter/material.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

/// Stub implementation of launchRazorpayPayment for mobile/desktop.
Future<Map<String, String>?> launchRazorpayPayment({
  required BuildContext context,
  required String key,
  required int amount,
  required String currency,
  required String orderId,
  required String planName,
  required String planDurationLabel,
}) async {
  final result = await showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Razorpay Mock Payment'),
      content: Text(
        'Plan: $planName\n'
        'Amount: INR ${(amount / 100).toStringAsFixed(2)}\n\n'
        'Simulate payment success for testing?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, {
            'paymentId': 'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
            'orderId': orderId,
            'signature': 'signature_mock_value',
          }),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: const Text('Simulate Success'),
        ),
      ],
    ),
  );
  return result;
}
