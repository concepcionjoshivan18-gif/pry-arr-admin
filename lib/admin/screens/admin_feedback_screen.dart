import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/review.dart';
import '../../core/components/pagination_controls.dart';
import '../components/app_back_button.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/responsive_page_header.dart';
import '../../core/components/skeleton_loader.dart';
import '../components/admin_scaffold.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _currentPage = 1;
  static const int _itemsPerPage = 6;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _buildHardwareBackground(),
        SafeArea(
          child: Column(
            children: [
              // Header Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: ResponsivePageHeader(
                  icon: Icons.reviews_rounded,
                  title: 'Customer Feedback & Ratings',
                ),
              ),
              const SizedBox(height: 8),
                // Search Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: p.text),
                    decoration: InputDecoration(
                      hintText: 'Search feedback by product or customer name...',
                      hintStyle: TextStyle(color: p.faint),
                      prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: p.faint),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                          : null,
                      filled: true,
                      fillColor: p.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: p.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: p.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: hwOrange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() => _currentPage = 1),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ReviewModel>>(
                    stream: firestoreService.streamAllReviews(),
                    builder: (context, snapshot) {
                      if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: 4,
                          itemBuilder: (_, __) => const SkeletonCard(),
                        );
                      }
                      final allReviews = snapshot.data ?? [];

                      final query = _searchCtrl.text.toLowerCase();
                      final filtered = allReviews.where((r) {
                        return r.productName.toLowerCase().contains(query) ||
                            r.userName.toLowerCase().contains(query) ||
                            r.comment.toLowerCase().contains(query);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text('No feedback found.', style: TextStyle(color: p.faint)),
                        );
                      }

                      // Average calculation
                      final totalRatingSum = filtered.fold<double>(0.0, (s, r) => s + r.rating);
                      final avgScore = totalRatingSum / filtered.length;

                      // Pagination
                      final totalPages = (filtered.length / _itemsPerPage).ceil();
                      if (_currentPage > totalPages) {
                        _currentPage = totalPages > 0 ? totalPages : 1;
                      }

                      final startIndex = (_currentPage - 1) * _itemsPerPage;
                      final pagedReviews = filtered.skip(startIndex).take(_itemsPerPage).toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Storewide Summary Card
                            _glass(
                              radius: 20,
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: hwYellow.withOpacity(0.16),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      avgScore.toStringAsFixed(1),
                                      style: TextStyle(
                                          fontSize: 28, fontWeight: FontWeight.bold, color: p.amber),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildStarRating(avgScore, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${filtered.length} Total Feedback Records',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Feedback submitted by customers after completed orders',
                                          style: TextStyle(fontSize: 12, color: p.faint),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Reviews List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pagedReviews.length,
                              itemBuilder: (context, index) {
                                final r = pagedReviews[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _glass(
                                    radius: 16,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: hwSteel,
                                              backgroundImage:
                                              r.userPhoto != null ? NetworkImage(r.userPhoto!) : null,
                                              child: r.userPhoto == null
                                                  ? Text(
                                                r.userName.isNotEmpty ? r.userName[0].toUpperCase() : 'U',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, color: Colors.white),
                                              )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(r.userName,
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.bold, color: p.text)),
                                                      Text(
                                                        DateFormat('MMM dd, yyyy HH:mm').format(r.createdAt),
                                                        style: TextStyle(fontSize: 11, color: p.faint),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Item: ${r.productName} ${r.orderId != null ? "(Order #${r.orderId!.substring(0, 5)})" : ""}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: Color(0xFF4FA3FF)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _buildStarRating(r.rating, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${r.rating.toStringAsFixed(1)} Stars',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: p.amber),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          r.comment,
                                          style: TextStyle(color: p.sub, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Pagination
                            Theme(
                              data: Theme.of(context).copyWith(
                                iconTheme: IconThemeData(color: p.faint),
                                textTheme: Theme.of(context).textTheme.apply(bodyColor: p.faint),
                              ),
                              child: PaginationControls(
                                currentPage: _currentPage,
                                totalPages: totalPages,
                                onPageChanged: (newPage) {
                                  setState(() {
                                    _currentPage = newPage;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star_rounded, color: hwYellow, size: size);
        } else if (index < rating && rating % 1 != 0) {
          return Icon(Icons.star_half_rounded, color: hwYellow, size: size);
        } else {
          return Icon(Icons.star_border_rounded, color: hwYellow, size: size);
        }
      }),
    );
  }
}

Widget _buildHardwareBackground() => const SizedBox.shrink();

Widget _glass({
  required Widget child,
  double radius = 24,
  EdgeInsetsGeometry? padding,
}) {
  return Builder(
    builder: (context) {
      final p = Pal.of(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glassFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
