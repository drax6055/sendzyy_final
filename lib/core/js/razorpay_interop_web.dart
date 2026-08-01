import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';

@JS('openRazorpay')
external void _openRazorpay(JSObject options, JSFunction callback);

/// Web implementation of launchRazorpayPayment using JS interop.
Future<Map<String, String>?> launchRazorpayPayment({
  required BuildContext context,
  required String key,
  required int amount,
  required String currency,
  required String orderId,
  required String planName,
  required String planDurationLabel,
}) async {
  final completer = Completer<Map<String, String>?>();

  final options = {
    'key': key,
    'amount': amount,
    'currency': currency,
    'name': 'Send-O Panel',
    'description': '$planName - $planDurationLabel Access',
    'order_id': orderId,
    'theme': {'color': '#075E54'},
  }.jsify()! as JSObject;

  final callback = ((JSAny? paymentId, JSAny? orderId, JSAny? signature) {
    if (completer.isCompleted) return;
    final pid = paymentId?.dartify()?.toString() ?? '';
    if (pid.isEmpty) {
      completer.complete(null);
    } else {
      completer.complete({
        'paymentId': pid,
        'orderId': orderId?.dartify()?.toString() ?? '',
        'signature': signature?.dartify()?.toString() ?? '',
      });
    }
  }.toJS);

  _openRazorpay(options, callback);

  return completer.future;
}

