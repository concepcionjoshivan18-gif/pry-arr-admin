import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/theme/hardware_theme.dart';

class CurvedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final GlobalKey cartKey;

  const CurvedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.cartKey,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final uniqueItemCount = cartProvider.items.length;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final p = Pal.of(context);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding : 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Glass(
            radius: 32.5,
            child: SizedBox(
              height: 65,
              child: Stack(
                children: [
                  // Sliding indicator pill matching delivery style
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(-1.0 + (currentIndex * 1.0), 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hwOrange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  // Tab items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        context: context,
                        index: 0,
                        icon: Icons.storefront_rounded,
                        label: 'Shop',
                        p: p,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 1,
                        icon: Icons.shopping_cart_rounded,
                        label: 'Cart',
                        badgeCount: uniqueItemCount,
                        key: cartKey,
                        p: p,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 2,
                        icon: Icons.person_outline_rounded,
                        label: 'Account',
                        p: p,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
    Key? key,
    required Pal p,
  }) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(32.5),
        onTap: () => onTabSelected(index),
        child: SizedBox(
          height: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? hwOrange : p.sub,
                    size: 22,
                  ),
                  if (badgeCount > 0 && (index != 1 || !isSelected))
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: hwRust,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: ts(isSelected ? hwOrange : p.sub, 11, isSelected ? FontWeight.w800 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlyAnimationWidget extends StatefulWidget {
  final Offset start;
  final Offset end;
  final IconData icon;
  final VoidCallback onComplete;

  const FlyAnimationWidget({
    super.key,
    required this.start,
    required this.end,
    required this.icon,
    required this.onComplete,
  });

  @override
  State<FlyAnimationWidget> createState() => _FlyAnimationWidgetState();
}

class _FlyAnimationWidgetState extends State<FlyAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        final dx = widget.start.dx + (widget.end.dx - widget.start.dx) * value;
        final dy = widget.start.dy + (widget.end.dy - widget.start.dy) * value - (60 * math.sin(value * math.pi));
        final scale = 1.0 - (0.6 * value);

        return Positioned(
          left: dx - 20,
          top: dy - 20,
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      },
    );
  }
}
