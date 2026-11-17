import 'package:flutter/material.dart';

String cleanErrorMessage(String rawMessage) {
  String msg = rawMessage.trim();
  
  // Strip all leading Error: / Exception: prefixes recursively
  while (msg.startsWith('Error: ') || msg.startsWith('Exception: ')) {
    if (msg.startsWith('Error: ')) {
      msg = msg.substring(7).trim();
    } else if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11).trim();
    }
  }

  // If the message contains specific known user errors, extract them directly
  if (msg.contains('Cannot accept order:')) {
    int idx = msg.indexOf('Cannot accept order:');
    msg = msg.substring(idx).trim();
  } else if (msg.contains('Insufficient stock')) {
    int idx = msg.indexOf('Insufficient stock');
    msg = msg.substring(idx).trim();
  } else if (msg.contains('Order cannot be cancelled')) {
    int idx = msg.indexOf('Order cannot be cancelled');
    msg = msg.substring(idx).trim();
  }

  return msg;
}

void showTopNotification(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = true,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final cleanMsg = cleanErrorMessage(message);
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => TopToastNotification(
      message: cleanMsg,
      isError: isError,
      isSuccess: isSuccess,
      icon: icon,
      onDismiss: () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      },
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(duration, () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

class TopToastNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isSuccess;
  final IconData? icon;
  final VoidCallback onDismiss;

  const TopToastNotification({
    super.key,
    required this.message,
    this.isError = false,
    this.isSuccess = true,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<TopToastNotification> createState() => _TopToastNotificationState();
}

class _TopToastNotificationState extends State<TopToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final color = widget.isError
        ? const Color(0xFFD93838)
        : (widget.isSuccess
            ? const Color(0xFF1B8A4B)
            : const Color(0xFFFF7A1A));
    final iconData = widget.icon ??
        (widget.isError
            ? Icons.error_outline_rounded
            : (widget.isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded));

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(iconData, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showTopError(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
  showTopNotification(context, message, isError: true, isSuccess: false, duration: duration);
}

void showTopSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
  showTopNotification(context, message, isError: false, isSuccess: true, duration: duration);
}

Future<void> confirmAndSignOut(BuildContext context, dynamic authService) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await authService.signOut();
  }
}
