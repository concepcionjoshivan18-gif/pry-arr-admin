import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_helper.dart';

class ProfilePicturePicker extends StatefulWidget {
  final String? initialUrl;
  final String initials;
  final Function(Uint8List? bytes, bool isRemoved) onImageSelected;

  const ProfilePicturePicker({
    super.key,
    this.initialUrl,
    required this.initials,
    required this.onImageSelected,
  });

  @override
  State<ProfilePicturePicker> createState() => _ProfilePicturePickerState();
}

class _ProfilePicturePickerState extends State<ProfilePicturePicker> {
  Uint8List? _selectedBytes;
  bool _isRemoved = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      
      // Validation: 2MB = 2 * 1024 * 1024 bytes
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large. Max 2MB allowed.')),
          );
        }
        return;
      }

      if (mounted) {
        final bool? confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Profile Picture'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Do you want to use this image as your new profile picture?'),
                const SizedBox(height: 16),
                CircleAvatar(radius: 50, backgroundImage: MemoryImage(bytes)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true), child: const Text('Use this picture')),
            ],
          ),
        );

        if (mounted && confirm == true) {
          setState(() {
            _selectedBytes = bytes;
            _isRemoved = false;
          });
          widget.onImageSelected(bytes, false);
        }
      }
    }
  }

  Future<void> _removeImage() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _selectedBytes = null;
        _isRemoved = true;
      });
      widget.onImageSelected(null, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (_selectedBytes != null && _selectedBytes!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 60,
        backgroundImage: MemoryImage(_selectedBytes!),
      );
    } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty && !_isRemoved) {
      final imgProvider = getAvatarImageProvider(widget.initialUrl);
      if (imgProvider != null) {
        avatar = CircleAvatar(
          radius: 60,
          backgroundImage: imgProvider,
        );
      } else {
        avatar = CircleAvatar(
          radius: 60,
          backgroundColor: Colors.blueGrey[100],
          child: Text(
            widget.initials,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        );
      }
    } else {
      avatar = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blueGrey[100],
        child: Text(
          widget.initials,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            avatar,
            Positioned(
              bottom: 0,
              right: 0,
              child: FloatingActionButton.small(
                onPressed: _pickImage,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ],
        ),
        if (_selectedBytes != null || (widget.initialUrl != null && widget.initialUrl!.isNotEmpty && !_isRemoved)) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _removeImage,
            child: const Text('Remove Picture', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
