import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService(this._storage);
  final FirebaseStorage _storage;

  Future<String> upload(String path, XFile file) async {
    final bytes = await file.readAsBytes();
    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Already gone or not ours - nothing to do.
    }
  }

  /// Deletes everything under a folder (used when cancelling a letter).
  Future<void> deleteFolder(String path) async {
    try {
      final list = await _storage.ref(path).listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {}
  }
}
