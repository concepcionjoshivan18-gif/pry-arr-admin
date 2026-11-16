import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider? getAvatarImageProvider(String? url) {
  if (url == null || url.isEmpty || url.length < 10) return null;
  try {
    if (url.startsWith('data:image')) {
      final parts = url.split(',');
      if (parts.length > 1) {
        final base64String = parts.last.trim();
        if (base64String.isNotEmpty) {
          final bytes = base64Decode(base64String);
          if (bytes.isNotEmpty) {
            return MemoryImage(bytes);
          }
        }
      }
    } else if (url.startsWith('http')) {
      return NetworkImage(url);
    } else if (!kIsWeb) {
      final file = File(url);
      if (file.existsSync() && file.lengthSync() > 0) {
        return FileImage(file);
      }
      final fileUri = File(url.replaceFirst('file://', ''));
      if (fileUri.existsSync() && fileUri.lengthSync() > 0) {
        return FileImage(fileUri);
      }
    }
  } catch (e) {
    debugPrint('Avatar Image decode error: $e');
  }
  return null;
}
