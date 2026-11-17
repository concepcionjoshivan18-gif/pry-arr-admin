import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppColors {
  static const orange = Color(0xFFFF7B1A);
  static const orangeDark = Color(0xFFD9541A);
  static const bgTop = Color(0xFF171A1E);
  static const bgBottom = Color(0xFF2B313B);
  static const muted = Color(0xFFA9AEB6);
}

/// Frosted-glass container, same look as the login card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withAlpha(36)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withAlpha(110),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/icons/badge.png', fit: BoxFit.cover),
      ),
    );
  }
}

class Blob extends StatelessWidget {
  final double size;
  final Color color;
  const Blob({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.bgTop, AppColors.bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -110,
            left: -110,
            child: Blob(size: 300, color: const Color(0xFF8A4A1E).withAlpha(150)),
          ),
          Positioned(
            bottom: -140,
            right: -120,
            child: Blob(size: 340, color: const Color(0xFF7A6A3A).withAlpha(110)),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _navBar(context),
                        const SizedBox(height: 40),
                        _hero(context),
                        const SizedBox(height: 48),
                        _features(),
                        const SizedBox(height: 40),
                        _stats(),
                        const SizedBox(height: 40),
                        _cta(context),
                        const SizedBox(height: 28),
                        const Text(
                          '© 2026 PRY-ARR Hardware. All rights reserved.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const LogoBadge(size: 40),
          const SizedBox(width: 10),
          const Text(
            'PRY-ARR',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign In',
                style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Column(
      children: [
        const LogoBadge(size: 84),
        const SizedBox(height: 24),
        const Text(
          'PRY-ARR Hardware',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.1),
        ),
        const SizedBox(height: 12),
        const Text(
          'Everything your hardware store needs,\nright in your pocket.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => context.go('/register'),
                child: const Text('Get Started',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            SizedBox(
              width: 200,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha(70)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => context.go('/login'),
                child: const Text('Sign In',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _features() {
    const items = [
      (Icons.inventory_2_outlined, 'Inventory', 'Track tools, materials and stock levels in real time.'),
      (Icons.shopping_cart_outlined, 'Orders', 'Browse products and place orders in a few taps.'),
      (Icons.local_shipping_outlined, 'Delivery', 'Follow your deliveries from store to doorstep.'),
      (Icons.receipt_long_outlined, 'Receipts', 'Keep a clear history of every purchase.'),
    ];

    return Column(
      children: [
        const Text('Why PRY-ARR?',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Built for builders, by people who know hardware.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 420 ? 2 : 1);
          const gap = 14.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final it in items)
                SizedBox(
                  width: w,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(it.$1, color: AppColors.orange),
                        ),
                        const SizedBox(height: 14),
                        Text(it.$2,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(it.$3,
                            style: const TextStyle(
                                color: AppColors.muted, height: 1.4, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _stats() {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orange)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        );

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Row(
        children: [
          stat('1,000+', 'Products'),
          stat('24/7', 'Access'),
          stat('Fast', 'Delivery'),
        ],
      ),
    );
  }

  Widget _cta(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const Text('Ready to get started?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Create your account in under a minute.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => context.go('/register'),
              child: const Text('Create Account',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text('Already have an account?',
                    style: TextStyle(color: AppColors.muted),
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign In',
                    style: TextStyle(
                        color: AppColors.orange, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
