import 'package:flutter/material.dart';
import '../theme/hardware_theme.dart';

class BootStep {
  final String label;
  final Future<void> Function() run;
  final double weight;
  const BootStep({required this.label, required this.run, this.weight = 1});
}

class BootScreen extends StatefulWidget {
  final List<BootStep> steps;
  final VoidCallback onDone;

  const BootScreen({super.key, required this.steps, required this.onDone});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  String _label = 'Starting...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    _anim.value = 0;

    final total = widget.steps.fold<double>(0, (sum, s) => sum + s.weight);
    double done = 0;

    try {
      for (final step in widget.steps) {
        if (!mounted) return;
        setState(() => _label = step.label);
        try {
          await step.run();
        } catch (e) {
          debugPrint('Boot step error (${step.label}): $e');
        }
        done += step.weight;
        await _anim.animateTo(done / total, curve: Curves.easeOut);
      }
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) widget.onDone();
    } catch (e) {
      String msg;
      try {
        msg = e.toString();
      } catch (_) {
        msg = 'Try again.';
      }
      if (mounted) setState(() => _error = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SizedBox.expand(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Image.asset('assets/icons/badge.png', width: 220, fit: BoxFit.contain),
            const SizedBox(height: 24),
            const Text(
              'PRY-ARR Hardware',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _anim.value,
                        minHeight: 8,
                        color: hwOrange,
                        backgroundColor: const Color(0xFF2A2A2A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error ?? _label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _error != null ? Colors.redAccent : Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${(_anim.value * 100).round()}%',
                          style: const TextStyle(
                            color: hwOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _run,
                          child: const Text('Retry', style: TextStyle(color: hwOrange)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
