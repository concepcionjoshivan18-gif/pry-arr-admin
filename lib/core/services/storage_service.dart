import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProductImage(String fileName, Uint8List fileBytes) async {
    // Return base64 data URL directly to ensure instant upload without network/CORS hangs
    return 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
  }

  Future<String> uploadProfilePicture(String uid, Uint8List fileBytes) async {
    // Return base64 data URL directly across all platforms (Web, Mobile, Desktop)
    // This avoids any platform channel / path_provider / _Namespace errors completely.
    return 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
  }
}
