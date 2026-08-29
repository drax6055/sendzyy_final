// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void webReloadPage() {
  html.window.location.reload();
}

void webClearStorageAndReload() {
  try {
    html.window.localStorage.clear();
    html.window.sessionStorage.clear();
    final serviceWorker = html.window.navigator.serviceWorker;
    if (serviceWorker != null) {
      serviceWorker.getRegistrations().then((registrations) {
        for (final reg in registrations) {
          if (reg is html.ServiceWorkerRegistration) {
            reg.unregister();
          }
        }
      });
    }
    html.window.caches?.keys().then((keys) {
      for (final key in keys) {
        html.window.caches?.delete(key);
      }
    });
  } catch (_) {}
  html.window.location.reload();
}

void webOpenUrl(String url) {
  html.window.open(url, '_blank');
}

Future<void> webDownloadBytes(
  List<int> bytes,
  String filename, {
  String mimeType = 'text/csv',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void registerWebAudioElement(String viewId, String audioUrl) {
  try {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final audio = html.AudioElement()
        ..src = audioUrl
        ..controls = true
        ..style.width = '100%'
        ..style.height = '40px'
        ..style.outline = 'none';
      return audio;
    });
  } catch (_) {}
}

void registerWebVideoElement(String viewId, String videoUrl) {
  try {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final video = html.VideoElement()
        ..src = videoUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '8px'
        ..preload = 'metadata'
        ..muted = true;
      video.onLoadedMetadata.listen((_) {
        video.currentTime = 0.1;
      });
      return video;
    });
  } catch (_) {}
}

void setupWebBeforeUnload() {
  try {
    html.window.onBeforeUnload.listen((html.Event event) {
      if (event is html.BeforeUnloadEvent) {
        event.returnValue = 'Are you sure you want to exit? If a campaign or broadcast is in progress, leaving may interrupt it.';
      }
    });
  } catch (_) {}
}

void webRedirect(String url) {
  try {
    html.window.location.href = url;
  } catch (_) {}
}

void webClearUrlQueryParams(String title) {
  try {
    final newUrl = '${html.window.location.origin}/';
    html.window.history.replaceState(null, title, newUrl);
  } catch (_) {}
}
