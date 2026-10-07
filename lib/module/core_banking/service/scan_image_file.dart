import 'dart:io';

/// The one scan photo a screen holds. Camera and picker paths are app-owned
/// cache copies, so a photo is deleted as soon as it is no longer shown.
class ScanImageFile {
  String? _path;

  String? get path => _path;

  /// Holds [path] and deletes the photo held before it.
  void replace(String path) {
    final previous = _path;
    _path = path;
    if (previous != null && previous != path) _delete(previous);
  }

  /// Deletes the held photo.
  void clear() {
    final current = _path;
    _path = null;
    if (current != null) _delete(current);
  }

  static void _delete(String path) {
    try {
      File(path).deleteSync();
    } on FileSystemException {
      // Already gone.
    }
  }
}
