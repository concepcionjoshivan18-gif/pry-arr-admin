import 'dart:convert';
import 'package:flutter/material.dart';

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
  String? path = imageUrl;

  if (path != null && path.trim().startsWith('data:image')) {
    try {
      final parts = path.trim().split(',');
      if (parts.length > 1 && parts.last.trim().isNotEmpty) {
        final cleanBase64 = parts.last.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.orange.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.hardware_rounded, size: 28, color: Colors.orange),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('ItemImageHelper base64 decode error: $e');
    }
  }

  if ((path == null || path.trim().isEmpty) && itemName != null) {
    final lower = itemName.toLowerCase();
    if (lower.contains('drill')) {
      path = 'drill.jpeg';
    } else if (lower.contains('tape') || lower.contains('etape')) {
      path = 'etape.jpeg';
    } else if (lower.contains('hollowblock') || lower.contains('hollow block') || lower.contains('block')) {
      path = 'hollowblocks.jpeg';
    } else if (lower.contains('philip') || lower.contains('screw driver') || lower.contains('screwdriver') || lower.contains('screw')) {
      path = 'philip.jpeg';
    } else if (lower.contains('flat')) {
      path = 'flat.jpeg';
    } else if (lower.contains('hammer')) {
      path = 'hammer.jpeg';
    } else if (lower.contains('concrete nail') || lower.contains('concretenail')) {
      path = 'concretenails.jpeg';
    } else if (lower.contains('nail') || lower.contains('standard nail')) {
      path = 'standardnails.jpeg';
    } else if (lower.contains('wire') || lower.contains('ewire') || lower.contains('cable') || lower.contains('cord')) {
      path = 'ewire.jpeg';
    } else if (lower.contains('metal hacksaw') || lower.contains('metal saw')) {
      path = 'metalhacksaw.jpeg';
    } else if (lower.contains('saw') || lower.contains('wood') || lower.contains('hacksaw')) {
      path = 'woodenhacksaw.jpeg';
    }
  }

  if (path == null || path.trim().isEmpty) {
    return Container(
      color: Colors.orange.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.hardware_rounded, size: 28, color: Colors.orange),
      ),
    );
  }

  final trimmed = path.trim();

  // Local asset path (e.g. "drill.jpeg", "items/drill.jpeg", "images/items/drill.jpeg", "assets/images/items/drill.jpeg", etc.)
  if (!trimmed.startsWith('http') && !trimmed.startsWith('blob:')) {
    String assetPath = trimmed;
    if (!assetPath.startsWith('assets/')) {
      if (assetPath.startsWith('images/')) {
        assetPath = 'assets/$assetPath';
      } else if (assetPath.startsWith('items/')) {
        assetPath = 'assets/images/$assetPath';
      } else {
        assetPath = 'assets/images/items/$assetPath';
      }
    }

    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.orange.withValues(alpha: 0.15),
        child: const Center(
          child: Icon(Icons.hardware_rounded, size: 28, color: Colors.orange),
        ),
      ),
    );
  }

  // Network image URL
  return Image.network(
    trimmed,
    fit: fit,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        color: Colors.orange.withValues(alpha: 0.1),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) => Container(
      color: Colors.orange.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(Icons.hardware_rounded, size: 28, color: Colors.orange),
      ),
    ),
  );
}
