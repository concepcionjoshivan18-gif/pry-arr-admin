import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/hardware_theme.dart';

class HoverSidebar extends StatefulWidget {
  final String currentRoute;
  final VoidCallback onSignOut;

  const HoverSidebar({
    super.key,
    required this.currentRoute,
    required this.onSignOut,
  });

  static const items = [
    ('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
    ('Inventory', Icons.inventory_2_outlined, '/admin/inventory'),
    ('Pending Payments', Icons.payments_rounded, '/admin/pending-payments'),
    ('Sales', Icons.point_of_sale_rounded, '/admin/sales'),
    ('Accounts', Icons.badge_outlined, '/admin/accounts'),
    ('Payroll', Icons.account_balance_wallet_outlined, '/admin/payroll'),
    ('Feedback', Icons.rate_review_outlined, '/admin/feedback'),
    ('Support Messages', Icons.chat_bubble_outline_rounded, '/admin/chat'),
    ('Admin Profile', Icons.admin_panel_settings_outlined, '/admin/profile'),
  ];

  @override
  State<HoverSidebar> createState() => _HoverSidebarState();
}

class _HoverSidebarState extends State<HoverSidebar> {
  bool _expanded = false;

  int get _selectedIndex {
    final loc = widget.currentRoute;
    if (loc.startsWith('/admin/dashboard')) return 0;
    if (loc.startsWith('/admin/inventory') || loc.startsWith('/admin/categories') || loc.startsWith('/admin/products')) return 1;
    if (loc.startsWith('/admin/pending-payments')) return 2;
    if (loc.startsWith('/admin/sales')) return 3;
    if (loc.startsWith('/admin/accounts')) return 4;
    if (loc.startsWith('/admin/payroll')) return 5;
    if (loc.startsWith('/admin/feedback')) return 6;
    if (loc.startsWith('/admin/chat')) return 7;
    if (loc.startsWith('/admin/profile')) return 8;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final auth = Provider.of<AuthService>(context);
    final sidebarColor = p.dark ? const Color(0xFF181C26) : const Color(0xFF1F2430);
    final activeTabColor = p.dark ? hwCharcoal : const Color(0xFFF8F5F0);

    final selected = _selectedIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: _expanded ? 260 : 80,
        decoration: BoxDecoration(
          color: sidebarColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.dark ? 0.4 : 0.15),
              blurRadius: 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 28),
            // Header / logo / profile avatar
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
                    Navigator.pop(context);
                  }
                  context.go('/admin/profile');
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [hwOrange, hwRust]),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: auth.currentUser?.profilePhoto != null && auth.currentUser!.profilePhoto!.isNotEmpty
                            ? Image.network(
                                auth.currentUser!.profilePhoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset('assets/icons/badge.png', height: 24, fit: BoxFit.contain),
                              )
                            : Image.asset('assets/icons/badge.png', height: 24, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _expanded ? 1 : 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRY-ARR Admin',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              auth.currentUser?.fullName.isNotEmpty == true ? auth.currentUser!.fullName : 'System Admin',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < HoverSidebar.items.length; i++)
                      _NavTile(
                        label: HoverSidebar.items[i].$1,
                        icon: HoverSidebar.items[i].$2,
                        active: i == selected,
                        expanded: _expanded,
                        activeColor: activeTabColor,
                        sidebarColor: sidebarColor,
                        onTap: () {
                          if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
                            Navigator.pop(context);
                          }
                          context.go(HoverSidebar.items[i].$3);
                        },
                      ),
                  ],
                ),
              ),
            ),
            _NavTile(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              active: false,
              expanded: _expanded,
              isLogout: true,
              activeColor: activeTabColor,
              sidebarColor: sidebarColor,
              onTap: widget.onSignOut,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool expanded;
  final bool isLogout;
  final Color activeColor;
  final Color sidebarColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.expanded,
    required this.activeColor,
    required this.sidebarColor,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isLogout
        ? Colors.redAccent
        : (widget.active ? hwOrange : (_hovered ? Colors.white : Colors.white70));
    final textColor = widget.isLogout
        ? Colors.redAccent
        : (widget.active ? hwOrange : (_hovered ? Colors.white : Colors.white70));

    final hoverColor = Colors.white.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.active) ...[
              Positioned(
                top: -22,
                right: 0,
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _CornerPainter(top: true, color: widget.activeColor),
                ),
              ),
              Positioned(
                bottom: -22,
                right: 0,
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _CornerPainter(top: false, color: widget.activeColor),
                ),
              ),
            ],
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 52,
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: widget.active 
                      ? widget.activeColor 
                      : (_hovered ? hoverColor : Colors.transparent),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(26)),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: iconColor, size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: widget.expanded ? 1 : 0,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final Color color;
  _CornerPainter({required this.top, required this.color});

  @override
  paint(Canvas canvas, Size size) {
    final r = size.width;
    final path = Path();
    if (top) {
      path
        ..moveTo(r, 0)
        ..lineTo(r, r)
        ..lineTo(0, r)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), math.pi / 2, -math.pi / 2, false)
        ..close();
    } else {
      path
        ..moveTo(r, r)
        ..lineTo(r, 0)
        ..lineTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset(0, r), radius: r), -math.pi / 2, math.pi / 2, false)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color || old.top != top;
}
