import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Work photos for a provider's listing, stored in Firebase Storage at
/// providers/{uid}/gallery/{time}.jpg. Customers see them on the listing.
class GalleryService {
  static final _picker = ImagePicker();

  /// Lets the provider pick photos (resized so uploads stay quick), up to [limit].
  static Future<List<XFile>> pick({required int limit}) async {
    if (limit <= 0) return const [];
    final files = await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82, limit: limit > 1 ? limit : null);
    return files.take(limit).toList();
  }

  /// Uploads one photo and returns its download link.
  static Future<String> upload(XFile file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in again.');
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) throw StateError('That photo is too big (8 MB max).');
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref('providers/$uid/gallery/$name');
    await ref.putData(bytes, SettableMetadata(contentType: _contentType(file)));
    return ref.getDownloadURL();
  }

  /// Removes a photo from Storage. Ignores photos that are already gone.
  static Future<void> delete(String url) async {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
  }

  static String _contentType(XFile f) {
    final mime = f.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.heic')) return 'image/heic';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
