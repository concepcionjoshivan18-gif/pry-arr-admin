import 'dart:convert';
import 'package:flutter/material.dart';

/// Returns the first usable image source from a raw value.
/// Handles a single data URI, a plain URL, and legacy values where
/// several data URIs were joined with ", ".
String? firstImageSource(String? raw) {
  if (raw == null) return null;
  final parts = raw
      .split(RegExp(r',\s*(?=data:image|https?://)'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts.first;
}

Widget _placeholder() => Container(
      color: Colors.orange.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.hardware_rounded, size: 28, color: Colors.orange),
      ),
    );

Widget _broken() => Container(
      color: Colors.orange.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.broken_image, size: 28, color: Colors.orange),
      ),
    );

class ItemImageHelper {
  static Widget buildImageWidget(String? itemName, {String? imageUrl, double size = 48}) {
    return SizedBox(
      width: size,
      height: size,
      child: buildItemImage(imageUrl, itemName: itemName),
    );
  }
}

Widget buildItemImage(String? imageUrl, {String? itemName, BoxFit fit = BoxFit.cover}) {
  final src = firstImageSource(imageUrl);
  if (src == null) return _placeholder();

  if (src.startsWith('data:image')) {
    try {
      final b64 = src.substring(src.indexOf(',') + 1).replaceAll(RegExp(r'\s+'), '');
      return Image.memory(
        base64Decode(b64),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _broken(),
      );
    } catch (e) {
      debugPrint('buildItemImage base64 decode error: $e');
      return _broken();
    }
  }

  return Image.network(
    src,
    fit: fit,
    errorBuilder: (_, __, ___) => _broken(),
  );
}
