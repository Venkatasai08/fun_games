// lib/draftclash/services/cloudinary_service.dart
//
// Uploads images to Cloudinary using an unsigned upload preset.
// Free plan: 25 GB storage, 25 GB bandwidth/month.
//
// Setup (one-time):
//   1. Create free account at https://cloudinary.com
//   2. Dashboard → Settings → Upload → Upload presets → Add preset
//      • Signing mode: Unsigned
//      • Folder: draftclash  (optional)
//   3. Copy your Cloud name from the dashboard top-left
//   4. Run app with:
//      --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name
//      --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset_name
//
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const _cloudName    = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const _uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static Uri get _uploadUrl => Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
  );

  static void _assertConfigured() {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary is not configured.\n'
        'Run with:\n'
        '  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name\n'
        '  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset_name',
      );
    }
  }

  /// Uploads a [File] (picked by user) to Cloudinary.
  /// Returns the secure CDN URL.
  static Future<String> uploadImage(File imageFile) async {
    _assertConfigured();
    final bytes = await imageFile.readAsBytes();
    return _uploadBytes(bytes, 'image/jpeg');
  }

  /// Downloads an image from [imageUrl], then uploads the raw bytes to
  /// Cloudinary. Returns the Cloudinary CDN URL.
  /// Returns '' silently if [imageUrl] is empty or the download fails —
  /// so callers don't need to guard against it.
  static Future<String> uploadImageFromUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return '';
    _assertConfigured();

    // ── 1. Download raw bytes from source URL ─────────────────────────────
    late Uint8List bytes;
    try {
      final res = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return '';
      bytes = res.bodyBytes;
    } catch (_) {
      return '';
    }

    // ── 2. Upload to Cloudinary ───────────────────────────────────────────
    try {
      // Detect format from URL extension; default to jpeg
      final ext = imageUrl.split('.').last.split('?').first.toLowerCase();
      final mime = ext == 'png' ? 'image/png'
                 : ext == 'webp' ? 'image/webp'
                 : 'image/jpeg';
      return await _uploadBytes(bytes, mime);
    } catch (_) {
      return '';
    }
  }

  // ── Core upload ───────────────────────────────────────────────────────────

  static Future<String> _uploadBytes(Uint8List bytes, String mime) async {
    final base64Data = base64Encode(bytes);

    final response = await http.post(
      _uploadUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'file':          'data:$mime;base64,$base64Data',
        'upload_preset': _uploadPreset,
        'folder':        'draftclash',
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error']?['message'] ?? 'Cloudinary upload failed');
    }

    return (jsonDecode(response.body) as Map<String, dynamic>)['secure_url']
        as String;
  }
}
