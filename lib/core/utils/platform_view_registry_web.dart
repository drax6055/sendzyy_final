import 'dart:ui_web' as ui_web;

/// Web implementation of registerWebPlatformView.
void registerWebPlatformView(String viewId, dynamic element) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) => element);
}
