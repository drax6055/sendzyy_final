// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

extension type _ContactBridge._(JSObject _) implements JSObject {
  external bool isSupported();
  external JSPromise<JSString> pick(bool multiple);
}

@JS('contactPickerBridge')
external _ContactBridge? get _contactPickerBridge;

bool isWebContactPickerSupported() {
  try {
    return _contactPickerBridge?.isSupported() ?? false;
  } catch (_) {
    return false;
  }
}

Future<List<Map<String, dynamic>>?> pickWebContacts({bool multiple = true}) async {
  try {
    if (!isWebContactPickerSupported()) return null;
    final bridge = _contactPickerBridge;
    if (bridge == null) return null;
    final jsResult = await bridge.pick(multiple).toDart;
    final jsonStr = jsResult.toDart;
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (decoded['success'] == true && decoded['contacts'] != null) {
      final list = (decoded['contacts'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      return list;
    }
    return null;
  } catch (e) {
    return null;
  }
}
