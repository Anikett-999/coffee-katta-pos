import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../providers/auth_provider.dart'; // To access authChangeNotifierProvider

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
  with WidgetsBindingObserver {
  static const Color _primary = Color(0xFF4A2C11); // Deep Espresso
  static const Color _background = Color(0xFFF9F6F0); // Warm Latte Cream
  static const Color _surface = Colors.white;
  static const Color _onSurface = Color(0xFF1C1C19);
  static const Color _onSurfaceVariant = Color(0xFF6F4E37); // Warm Roast
  static const Color _inputBackground = Color(0xFFF5EFEB); // Soft Latte Cream

  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  bool _autoRedirectTriggered = false;
  static const int _cooldownSeconds = 30;
  int _secondsLeft = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sent && !_autoRedirectTriggered) {
      _autoRedirectTriggered = true;
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Color(0xFF2E7D32), size: 28),
            SizedBox(width: 10),
            Text('Link Dispatched', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'A password reset link has been dispatched to $email.\n\nPlease check your inbox and spam/junk folder. Click the link in the email to set your new password, then return here to log in.',
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay Here', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _sendResetLink() async {
    if (_secondsLeft > 0) {
      return;
    }

    final email = _emailCtrl.text.trim();
    final emailError = _validateEmail(email);
    if (emailError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    final resetError = await ref.read(authChangeNotifierProvider).sendResetEmail(email);
    if (resetError != null) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resetError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_reset_email', email);
      await prefs.setInt('pending_reset_requested_at', DateTime.now().millisecondsSinceEpoch);

      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
      _showSuccessDialog(email);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send reset link. Please verify email and try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/branding/log-bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              color: _primary.withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 110),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A2C11).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/branding/splash_logo.png', 
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, size: 70, color: Color(0xFFD4A373)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 430),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 30,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Forgot Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Enter your registered email and we\'ll send a reset link.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 24),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Email Address',
                              style: TextStyle(
                                color: _onSurfaceVariant,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w500, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              hintStyle: const TextStyle(
                                color: Color.fromRGBO(89, 65, 64, 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.mail, color: _onSurfaceVariant),
                              filled: true,
                              fillColor: _inputBackground,
                              contentPadding: const EdgeInsets.symmetric(vertical: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: _primary, width: 1.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 64,
                            child: ElevatedButton(
                              onPressed: (_loading || _secondsLeft > 0) ? null : _sendResetLink,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color.fromRGBO(74, 44, 17, 0.24),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _secondsLeft > 0
                                          ? 'Resend in ${_secondsLeft}s'
                                          : 'Send Reset Link',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Back to Login',
                              style: TextStyle(color: _primary, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_sent) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(46, 125, 50, 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color.fromRGBO(46, 125, 50, 0.35)),
                              ),
                              child: const Text(
                                'After changing password from email link, return to Login and sign in. If needed, also check your spam folder for the reset email.',
                                style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
