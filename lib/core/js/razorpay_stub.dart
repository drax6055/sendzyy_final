import 'dart:async';
import 'package:flutter/foundation.dart';

Future<Map<String, String>?> triggerRazorpayPayment({
  required String key,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String orderId,
}) async {
  debugPrint('[Razorpay Stub] Razorpay JS Checkout is only supported on Web platform.');
  return null;
}
