import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/components/top_notification.dart';
import '../../services/shift_gate.dart';

// ---- Hardware Store palette (matches DashboardScreen) ----
const Color _hwCharcoal = Color(0xFF14171A);
const Color _hwSteel = Color(0xFF3A4048);
const Color _hwOrange = Color(0xFFFF7A1A);
const Color _hwSafetyYellow = Color(0xFFFFC53D);
const Color _hwRust = Color(0xFFB5482A);

class LoginScreen extends StatefulWidget {
  final bool showRegister;
  const LoginScreen({super.key, this.showRegister = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  AnimationController? _shakeController;

  int _failedLoginAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initShakeController();
  }

  void _initShakeController() {
    _shakeController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyAuthError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('time in') || str.contains('rfid')) {
      return error.toString().replaceAll('Exception: ', '');
    }
    if (str.contains('invalid-credential') ||
        str.contains('wrong-password') ||
        str.contains('user-not-found')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (str.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (str.contains('network-request-failed') ||
        str.contains('network') ||
        str.contains('socket')) {
      return 'No internet connection. Check your network and retry.';
    }
    if (str.contains('user-disabled')) {
      return 'This account has been disabled. Contact administrator.';
    }
    return 'Authentication failed. Please check your credentials.';
  }

  void _startLockoutTimer() {
    setState(() {
      _lockoutSeconds = 30;
      _errorMessage = null;
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds > 1) {
        if (mounted) {
          setState(() {
            _lockoutSeconds--;
          });
        }
      } else {
        _lockoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _lockoutSeconds = 0;
            _failedLoginAttempts = 0;
            _errorMessage = null;
          });
        }
      }
    });
  }

  void _submit() async {
    if (_lockoutSeconds > 0) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        _failedLoginAttempts = 0;
        _errorMessage = null;
      }
    } catch (e) {
      if (mounted) {
        _failedLoginAttempts++;
        _shakeController?.forward(from: 0);
        if (_failedLoginAttempts >= 5) {
          _startLockoutTimer();
        } else {
          setState(() {
            _errorMessage = _friendlyAuthError(e);
          });
        }
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your registered email address to receive a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  showTopNotification(
                    context,
                    'Password reset email sent to $email! Please check your inbox.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  showTopNotification(context, 'Error: $e', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _hwOrange, foregroundColor: Colors.white),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initShakeController();
    final authService = Provider.of<AuthService>(context);

    final bannerMsg = _lockoutSeconds > 0
        ? 'Too many failed attempts. Try again in ${_lockoutSeconds}s.'
        : _errorMessage;

    return Scaffold(
      backgroundColor: _hwCharcoal,
      body: Stack(
        children: [
          _buildHardwareBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AnimatedBuilder(
                    animation: _shakeController ?? const AlwaysStoppedAnimation(0.0),
                    builder: (context, child) {
                      final val = _shakeController?.value ?? 0.0;
                      final dx = math.sin(val * math.pi * 4) * 10 * (1 - val);
                      return Transform.translate(offset: Offset(dx, 0), child: child);
                    },
                    child: _glass(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_hwOrange, _hwRust]),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _hwOrange.withValues(alpha: 0.5),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.hardware_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'PRY-ARR Hardware',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Welcome Back',
                              style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),

                            // TOP GLASS ERROR BANNER
                            AuthErrorBanner(
                              message: bannerMsg,
                              attemptsLeft: _lockoutSeconds > 0 ? 0 : (5 - _failedLoginAttempts),
                            ),

                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              enabled: _lockoutSeconds == 0,
                              onChanged: (_) {
                                if (_errorMessage != null) setState(() => _errorMessage = null);
                              },
                              validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              enabled: _lockoutSeconds == 0,
                              onChanged: (_) {
                                if (_errorMessage != null) setState(() => _errorMessage = null);
                              },
                              validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white54,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _lockoutSeconds > 0 ? null : _showForgotPasswordDialog,
                                child: const Text('Forgot Password?', style: TextStyle(color: _hwOrange, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            authService.isLoading
                                ? const Center(
                              child: CircularProgressIndicator(color: _hwOrange),
                            )
                                : SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: (_lockoutSeconds > 0 || authService.isLoading) ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hwOrange,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF6E2828),
                                  disabledForegroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  _lockoutSeconds > 0 ? 'Locked (${_lockoutSeconds}s)' : 'Sign In',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.showRegister) ...[
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account?", style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  TextButton(
                                    onPressed: () => context.go('/register'),
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(color: _hwOrange, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    void Function(String)? onChanged,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hwOrange, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hwRust, width: 1.6),
        ),
      ),
    );
  }

  Widget _glass({required Widget child, double radius = 24, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHardwareBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_hwCharcoal, Color(0xFF1F2429), _hwSteel],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -80, left: -60, child: _blob(260, _hwOrange.withValues(alpha: 0.3))),
            Positioned(bottom: -100, right: -80, child: _blob(300, _hwSafetyYellow.withValues(alpha: 0.14))),
            Positioned(top: 320, right: 120, child: _blob(160, _hwRust.withValues(alpha: 0.2))),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  final String? message;
  final int attemptsLeft;

  const AuthErrorBanner({super.key, this.message, this.attemptsLeft = 0});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (attemptsLeft > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$attemptsLeft ${attemptsLeft == 1 ? "attempt" : "attempts"} left before lockout',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
