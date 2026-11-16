import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class OtpResult {
  final String code;
  final bool emailSent;
  final String? error;

  OtpResult({
    required this.code,
    required this.emailSent,
    this.error,
  });
}

class OtpService {
  static final String _smtpUsername = 'pryarrhardware@gmail.com';
  static final String _smtpPassword = 'oqfx yftb bdte buwp';
  static String? _latestOtp;
  static String? _latestRecipient;

  Future<OtpResult> sendOtp(String recipient, {String name = 'Valued Customer'}) async {
    final rand = math.Random();
    final otp = (100000 + rand.nextInt(900000)).toString();
    _latestOtp = otp;
    _latestRecipient = recipient.trim().toLowerCase();

    bool emailSent = false;
    String? lastError;

    // 1. On non-Web platforms (Android, iOS, Desktop), try raw TCP Gmail SMTP via package:mailer
    if (!kIsWeb) {
      final pwdWithSpaces = _smtpPassword;
      final pwdNoSpaces = _smtpPassword.replaceAll(' ', '');

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 20px auto; background: #ffffff; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header { text-align: center; color: #14171A; font-size: 24px; font-weight: bold; margin-bottom: 20px; }
    .code-box { background: #FFFaf4; border: 2px dashed #FF7A1A; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; color: #FF7A1A; letter-spacing: 6px; border-radius: 6px; margin: 20px 0; }
    .footer { font-size: 12px; color: #7f8c8d; text-align: center; margin-top: 30px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">PRY-ARR Hardware OMS</div>
    <p>Hello <b>$name</b>,</p>
    <p>Thank you for registering with <b>PRY-ARR Hardware OMS</b>. Please use the verification code below to complete your sign-up:</p>
    <div class="code-box">$otp</div>
    <p>This verification code will expire in <b>2 minutes</b>.</p>
    <p>If you didn't request this, please ignore this email.</p>
    <div class="footer">&copy; 2026 PRY-ARR Hardware OMS. All rights reserved.</div>
  </div>
</body>
</html>
''';

      final message = Message()
        ..from = Address(_smtpUsername, 'PRY-ARR Hardware OMS')
        ..recipients.add(recipient.trim())
        ..subject = 'Your Verification Code (OTP) - PRY-ARR Hardware OMS'
        ..text = 'Hello $name,\n\nYour verification code for PRY-ARR Hardware OMS is: $otp\n\nThis code expires in 2 minutes.'
        ..html = htmlContent;

      final configs = [
        gmail(_smtpUsername, pwdWithSpaces),
        gmail(_smtpUsername, pwdNoSpaces),
        SmtpServer('smtp.gmail.com', port: 587, username: _smtpUsername, password: pwdNoSpaces),
        SmtpServer('smtp.gmail.com', port: 587, username: _smtpUsername, password: pwdWithSpaces),
      ];

      for (int i = 0; i < configs.length; i++) {
        try {
          debugPrint('Sending OTP via Gmail SMTP config #${i + 1}...');
          await send(message, configs[i]);
          emailSent = true;
          lastError = null;
          debugPrint('SMTP Email OTP sent successfully via config #${i + 1} to $recipient');
          break;
        } catch (e) {
          lastError = e.toString();
          debugPrint('Gmail SMTP config #${i + 1} failed for $recipient: $e');
        }
      }
    }

    // 2. On Web environment (or if SMTP failed on Native), use HTTPS REST Email API
    if (!emailSent) {
      debugPrint('Attempting HTTPS REST Email API for $recipient (kIsWeb: $kIsWeb)...');
      try {
        final httpResult = await _sendViaHttpApi(recipient: recipient.trim(), name: name, otp: otp);
        if (httpResult.emailSent) {
          emailSent = true;
          lastError = null;
          debugPrint('HTTPS REST Email API sent successfully to $recipient');
        } else {
          lastError = httpResult.error ?? lastError ?? 'Failed to send via HTTPS REST Email API';
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('HTTPS REST Email API error: $e');
      }
    }

    return OtpResult(code: otp, emailSent: emailSent, error: lastError);
  }

  Future<OtpResult> _sendViaHttpApi({
    required String recipient,
    required String name,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://formsubmit.co/ajax/$recipient'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          '_subject': '🔐 Your Verification Code (OTP) - PRY-ARR Hardware OMS',
          '_template': 'box',
          '_captcha': 'false',
          'Verification Code': otp,
          'Message': 'Hello $name, your verification code for PRY-ARR Hardware OMS is: $otp. This code expires in 2 minutes.',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return OtpResult(code: otp, emailSent: true);
      } else {
        return OtpResult(
          code: otp,
          emailSent: false,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return OtpResult(code: otp, emailSent: false, error: e.toString());
    }
  }

  Future<bool> verifyOtp(String enteredCode, {String? recipient}) async {
    if (_latestOtp == null) return false;
    if (recipient != null && _latestRecipient != null) {
      if (recipient.trim().toLowerCase() != _latestRecipient) return false;
    }
    return enteredCode.trim() == _latestOtp;
  }
}
