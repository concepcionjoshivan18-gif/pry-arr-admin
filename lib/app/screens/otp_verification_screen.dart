import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/otp_service.dart';
import '../../core/theme/hardware_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String recipient;
  final VoidCallback onVerified;

  const OtpVerificationScreen({super.key, required this.recipient, required this.onVerified});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _emailSent = false;
  String? _statusMessage;
  String? _error;
  int _remainingSeconds = 120; // 2 minutes expiration timer
  Timer? _timer;
  bool _isExpired = false;

  int _resendCooldownSeconds = 60; // 60s Rate Limit for Resend button
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startResendCooldown();
    _sendCode();
  }

  void _startResendCooldown() {
    setState(() {
      _resendCooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldownSeconds > 1) {
        if (mounted) {
          setState(() {
            _resendCooldownSeconds--;
          });
        }
      } else {
        _cooldownTimer?.cancel();
        if (mounted) {
          setState(() {
            _resendCooldownSeconds = 0;
          });
        }
      }
    });
  }

  void _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _statusMessage = null;
      _error = null;
    });

    final result = await OtpService().sendOtp(widget.recipient);

    if (mounted) {
      setState(() {
        _isSendingCode = false;
        _emailSent = result.emailSent;
        if (result.emailSent) {
          _statusMessage = 'Verification code sent to ${widget.recipient}.\nPlease check your email inbox (and spam/junk folder).';
        } else {
          final errDetail = result.error != null && result.error!.isNotEmpty
              ? '\nDetail: ${result.error}'
              : '';
          _statusMessage = 'Failed to send email to ${widget.recipient}.$errDetail\nPlease tap "Resend Code".';
        }
      });
    }
  }

  void _startTimer() {
    _remainingSeconds = 120;
    _isExpired = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _isExpired = true;
            _error = 'OTP has expired. Please request a new code.';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _resendCode() async {
    _startTimer();
    _startResendCooldown();
    _sendCode();
  }

  void _verify() async {
    if (_isExpired) {
      setState(() => _error = 'OTP has expired. Please request a new code.');
      return;
    }

    if (_otpController.text.trim().length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await OtpService().verifyOtp(_otpController.text, recipient: widget.recipient);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      widget.onVerified();
    } else {
      setState(() => _error = 'Invalid OTP code. Please try again.');
    }
  }

  String get _timerFormatted {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.mark_email_read_outlined, color: hwOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'OTP Verification',
              style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Enter the 6-digit verification code sent to:\n${widget.recipient}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.faint, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_isSendingCode) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Sending email to recipient...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ] else if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _emailSent ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _emailSent ? Colors.green.withAlpha(100) : Colors.red.withAlpha(100),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _emailSent ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: _isExpired ? p.danger : hwOrange),
                const SizedBox(width: 6),
                Text(
                  _isExpired ? 'Expired' : 'Expires in: $_timerFormatted',
                  style: TextStyle(
                    color: _isExpired ? p.danger : hwOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_isExpired && !_isSendingCode,
              style: TextStyle(color: p.text, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '123456',
                hintStyle: TextStyle(color: p.faint.withAlpha(100), letterSpacing: 8),
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) {
                if (!_isLoading && !_isExpired && !_isSendingCode) {
                  _verify();
                }
              },
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: (_isSendingCode || _isLoading || _resendCooldownSeconds > 0) ? null : _resendCode,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(_resendCooldownSeconds > 0 ? 'Resend Code (${_resendCooldownSeconds}s)' : 'Resend Code'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _isExpired || _isSendingCode) ? null : _verify,
          style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('VERIFY'),
        ),
      ],
    );
  }
}
