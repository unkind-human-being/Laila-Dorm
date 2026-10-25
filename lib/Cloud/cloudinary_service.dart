import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cloudinary_config.dart';

class CloudinaryUploadResult {
  final bool success;

  final String? imageUrl;
  final String? publicId;
  final String? imageHash;

  final String message;

  const CloudinaryUploadResult({
    required this.success,
    required this.message,
    this.imageUrl,
    this.publicId,
    this.imageHash,
  });
}

class CloudinaryService {
  // ============================================================
  // CREATE IMAGE HASH
  // ============================================================

  static String imageHash(
    Uint8List bytes,
  ) {
    return sha256
        .convert(bytes)
        .toString();
  }

  // ============================================================
  // UPLOAD RESIDENT PHOTO
  // ============================================================

  static Future<CloudinaryUploadResult>
      uploadResidentPhoto({
    required Uint8List bytes,
    required String residentId,

    String? oldImageHash,
    String? oldImageUrl,
    String? oldPublicId,
  }) async {
    if (!CloudinaryConfig.configured) {
      return const CloudinaryUploadResult(
        success: false,
        message:
            'Cloud photo storage is not configured.',
      );
    }

    final String newHash =
        imageHash(bytes);

    // ==========================================================
    // EXACT SAME PICTURE?
    //
    // Don't upload again.
    // ==========================================================

    if (oldImageHash == newHash &&
        oldImageUrl != null &&
        oldImageUrl.isNotEmpty) {
      return CloudinaryUploadResult(
        success: true,

        message:
            'Picture is already backed up.',

        imageUrl:
            oldImageUrl,

        publicId:
            oldPublicId,

        imageHash:
            newHash,
      );
    }

    try {
      final Uri url =
          Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '${CloudinaryConfig.cloudName}'
        '/image/upload',
      );

      final request =
          http.MultipartRequest(
        'POST',
        url,
      );

      request.fields['upload_preset'] =
          CloudinaryConfig.uploadPreset;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,

          filename:
              'resident_$residentId.jpg',
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      dynamic data;

      try {
        data =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        data = null;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map) {
        return CloudinaryUploadResult(
          success: true,

          message:
              'Picture uploaded successfully.',

          imageUrl:
              data['secure_url']
                  ?.toString(),

          publicId:
              data['public_id']
                  ?.toString(),

          imageHash:
              newHash,
        );
      }

      return CloudinaryUploadResult(
        success: false,

        message:
            'Picture upload failed. HTTP ${response.statusCode}',
      );
    } catch (error) {
      return CloudinaryUploadResult(
        success: false,

        message:
            'Picture upload failed: $error',
      );
    }
  }

  // ============================================================
  // DOWNLOAD PICTURE
  //
  // Used when restoring to a new phone.
  // ============================================================

  static Future<Uint8List?>
      downloadPicture(
    String imageUrl,
  ) async {
    try {
      final response =
          await http.get(
        Uri.parse(
          imageUrl,
        ),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}

    return null;
  }
}