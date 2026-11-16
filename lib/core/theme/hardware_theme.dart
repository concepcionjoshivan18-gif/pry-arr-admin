import 'dart:ui';
import 'package:flutter/material.dart';

// ---- Hardware Store palette ----
const Color hwCharcoal = Color(0xFF14171A);
const Color hwSteel = Color(0xFF3A4048);
const Color hwOrange = Color(0xFFFF7A1A);
const Color hwYellow = Color(0xFFFFC53D);
const Color hwRust = Color(0xFFB5482A);

class ThemeController extends ChangeNotifier {
  bool _dark = true;
  bool get dark => _dark;
  ThemeMode get themeMode => _dark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _dark = !_dark;
    notifyListeners();
  }
}

/// Holds every color that changes between light and dark mode.
class Pal extends InheritedWidget {
  final bool dark;
  const Pal({super.key, required this.dark, required super.child});

  static Pal of(BuildContext c) {
    final pal = c.dependOnInheritedWidgetOfExactType<Pal>();
    if (pal != null) return pal;
    return const Pal(dark: true, child: SizedBox.shrink());
  }

  Color get text => dark ? Colors.white : hwCharcoal;
  Color get sub => dark ? Colors.white70 : hwSteel;
  Color get faint => dark ? Colors.white54 : Colors.black54;
  Color get amber => dark ? hwYellow : const Color(0xFFC98A00);
  Color get danger => dark ? const Color(0xFFFF6B5A) : hwRust;
  Color get ok => dark ? Colors.greenAccent : const Color(0xFF1B8A4B);
  Color get fill => dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.80);
  Color get line => dark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.10);
  Color get glassFill =>
      dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.72);
  Color get glassBorder =>
      dark ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.95);
  Color get shadow =>
      Colors.black.withValues(alpha: dark ? 0.30 : 0.08);
  Color get track =>
      dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07);
  Color get surface => dark ? const Color(0xFF1F2429) : const Color(0xFFFFFAF4);
  Color get grid =>
      dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07);
  List<Color> get gradient => dark
      ? const [hwCharcoal, Color(0xFF1F2429), hwSteel]
      : const [Color(0xFFF8F5F0), Color(0xFFFFEFE0), Color(0xFFECE8E1)];

  @override
  bool updateShouldNotify(Pal old) => old.dark != dark;
}

TextStyle ts(Color c, double s, [FontWeight w = FontWeight.w500]) =>
    TextStyle(color: c, fontSize: s, fontWeight: w);

String peso(num v) {
  final parts = v.toStringAsFixed(2).split('.');
  final integerPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '₱$integerPart.${parts[1]}';
}

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final k = p.dark ? 1.0 : 0.7;
    Widget blob(double s, Color c) => Container(
        width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.gradient),
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Stack(
          children: [
            Positioned(top: -80, left: -60, child: blob(280, hwOrange.withValues(alpha: 0.35 * k))),
            Positioned(bottom: -100, right: -80, child: blob(320, hwYellow.withValues(alpha: 0.18 * k))),
            Positioned(top: 240, right: 140, child: blob(180, hwRust.withValues(alpha: 0.22 * k))),
          ],
        ),
      ),
    );
  }
}

/// Frosted glass card used for every panel.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  const Glass({super.key, required this.child, this.radius = 24, this.padding});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: padding,
          decoration: BoxDecoration(
            color: p.glassFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: p.glassBorder, width: 1.2),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class ThemeSwitchWidget extends StatelessWidget {
  final bool dark;
  final VoidCallback onToggle;
  const ThemeSwitchWidget({super.key, required this.dark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Glass(
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (c, a) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(a),
              child: ScaleTransition(scale: a, child: c),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
              color: dark ? hwYellow : hwOrange,
            ),
          ),
        ),
      ),
    );
  }
}
