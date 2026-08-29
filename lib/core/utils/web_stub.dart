import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

void webReloadPage() {}

void webClearStorageAndReload() {}

void webOpenUrl(String url) {
  // On native mobile/desktop platforms, url_launcher or native handling can be invoked if needed.
  debugPrint('[WebHelper Stub] Opening URL: $url');
}

Future<void> webDownloadBytes(
  List<int> bytes,
  String filename, {
  String mimeType = 'text/csv',
}) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    dir ??= await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    debugPrint('[WebHelper Stub] Saved file to: ${file.path}');
  } catch (e) {
    debugPrint('[WebHelper Stub] Save file error: $e');
  }
}

void registerWebAudioElement(String viewId, String audioUrl) {}
void registerWebVideoElement(String viewId, String videoUrl) {}

void setupWebBeforeUnload() {}

void webRedirect(String url) {}
void webClearUrlQueryParams(String title) {}
