import 'package:flutter/material.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/responsive.dart';

class ResponsivePageHeader extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final List<Widget> actions;
  final String? breadcrumb;

  const ResponsivePageHeader({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.actions = const [],
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final isMobile = Breakpoints.isMobile(context);

    final leadingWidget = leading ?? (icon != null ? Icon(icon, color: hwOrange, size: isMobile ? 24 : 26) : const SizedBox.shrink());

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leadingWidget,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: ts(p.text, 20, FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (breadcrumb != null) ...[
            const SizedBox(height: 2),
            Text(breadcrumb!, style: ts(p.faint, 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leadingWidget,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ts(p.text, 24, FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (breadcrumb != null) ...[
                const SizedBox(height: 2),
                Text(breadcrumb!, style: ts(p.faint, 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}
