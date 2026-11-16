import 'package:flutter/material.dart';
import 'package:pry_arr/core/utils/item_image_helper.dart';

class SwipableImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  final String? itemName;
  final double height;
  final BorderRadius? borderRadius;

  const SwipableImageSlider({
    super.key,
    required this.imageUrls,
    this.itemName,
    this.height = 250,
    this.borderRadius,
  });

  @override
  State<SwipableImageSlider> createState() => _SwipableImageSliderState();
}

class _SwipableImageSliderState extends State<SwipableImageSlider> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> urls = widget.imageUrls.where((url) => url.trim().isNotEmpty).toList();
    
    // If no urls provided, fallback to item name based asset if possible
    if (urls.isEmpty && widget.itemName != null) {
      final lower = widget.itemName!.toLowerCase();
      if (lower.contains('drill')) {
        urls = ['drill.jpeg'];
      } else if (lower.contains('tape') || lower.contains('etape')) {
        urls = ['etape.jpeg'];
      }
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(20);

    if (urls.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: buildItemImage(null, itemName: widget.itemName),
        ),
      );
    }

    if (urls.length == 1) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: buildItemImage(urls.first, itemName: widget.itemName),
        ),
      );
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return buildItemImage(urls[index], itemName: widget.itemName);
              },
            ),
            // Page Indicator Dots at bottom center
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (index) {
                  return Container(
                    width: _currentIndex == index ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            // Image count badge top right (e.g. "1 / 2")
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${urls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
