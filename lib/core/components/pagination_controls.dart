import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    const double btnSize = 42.0;
    const double borderRadius = 10.0;
    const activeColor = Color(0xFFFF7043); // Vibrant orange matching theme

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            // Previous Arrow Button (<)
            InkWell(
              onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                width: btnSize,
                height: btnSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: currentPage > 1 ? Colors.black87 : Colors.grey[300],
                ),
              ),
            ),

            // Page Numbers (1, 2, 3...)
            ...List.generate(totalPages, (index) {
              final pageNum = index + 1;
              final isSelected = pageNum == currentPage;

              return InkWell(
                onTap: () => onPageChanged(pageNum),
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  width: btnSize,
                  height: btnSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }),

            // Next Arrow Button (>)
            InkWell(
              onTap: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                width: btnSize,
                height: btnSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: currentPage < totalPages ? Colors.black87 : Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
