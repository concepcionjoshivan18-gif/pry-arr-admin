import 'dart:convert';
import 'dart:typed_data';

class StorageService {
  Future<String> compressToDataUri(
    Uint8List bytes, {
    int maxByteLimit = 150 * 1024,
  }) async {
    if (bytes.length > maxByteLimit) {
      throw Exception('Image is still too large. Please choose a smaller image.');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<String> uploadProductImage(String fileName, Uint8List fileBytes) {
    return compressToDataUri(fileBytes, maxByteLimit: 150 * 1024);
  }

  Future<String> uploadProfilePicture(String uid, Uint8List fileBytes) {
    return compressToDataUri(fileBytes, maxByteLimit: 60 * 1024);
  }
}
