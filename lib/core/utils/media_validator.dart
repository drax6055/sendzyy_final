import 'package:file_picker/file_picker.dart';

class MediaValidator {
  static const int _imageSizeLimit = 5 * 1024 * 1024;   // 5 MB
  static const int _videoSizeLimit = 16 * 1024 * 1024;  // 16 MB
  static const int _documentSizeLimit = 100 * 1024 * 1024; // 100 MB

  static const List<String> _imageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> _videoExtensions = ['mp4'];
  static const List<String> _documentExtensions = ['pdf'];

  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateImage(PlatformFile file) {
    final ext = _extension(file);
    if (!_imageExtensions.contains(ext)) {
      return 'Image must be JPG or PNG and under 5 MB.';
    }
    if ((file.size) > _imageSizeLimit) {
      return 'Image must be JPG or PNG and under 5 MB.';
    }
    return null;
  }

  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateVideo(PlatformFile file) {
    final ext = _extension(file);
    if (!_videoExtensions.contains(ext)) {
      return 'Video must be MP4 and under 16 MB.';
    }
    if ((file.size) > _videoSizeLimit) {
      return 'Video must be MP4 and under 16 MB.';
    }
    return null;
  }

  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateDocument(PlatformFile file) {
    final ext = _extension(file);
    if (!_documentExtensions.contains(ext)) {
      return 'Document must be PDF and under 100 MB.';
    }
    if ((file.size) > _documentSizeLimit) {
      return 'Document must be PDF and under 100 MB.';
    }
    return null;
  }

  static String _extension(PlatformFile file) {
    final name = file.name.toLowerCase();
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1);
  }
}
