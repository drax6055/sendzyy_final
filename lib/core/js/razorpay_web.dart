// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

@JS('openRazorpay')
external void _openRazorpay(JSObject options, JSFunction callback);

Future<Map<String, String>?> triggerRazorpayPayment({
  required String key,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String orderId,
}) async {
  final completer = Completer<Map<String, String>?>();

  final options = {
    'key': key,
    'amount': amount,
    'currency': currency,
    'name': name,
    'description': description,
    'order_id': orderId,
    'theme': {'color': '#075E54'},
  }.jsify()! as JSObject;

  final callback = ((JSAny? paymentId, JSAny? orderIdRes, JSAny? signature) {
    if (completer.isCompleted) return;
    final pid = paymentId?.dartify()?.toString() ?? '';
    if (pid.isEmpty) {
      completer.complete(null);
    } else {
      completer.complete({
        'paymentId': pid,
        'orderId': orderIdRes?.dartify()?.toString() ?? '',
        'signature': signature?.dartify()?.toString() ?? '',
      });
    }
  }.toJS);

  _openRazorpay(options, callback);

  return completer.future;
}
