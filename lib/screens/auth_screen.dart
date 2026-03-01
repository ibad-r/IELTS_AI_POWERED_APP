import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  int _step = 0; // 0 = email, 1 = password
  bool _isNewUser = false;
  bool _obscurePass = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _resetLoading = false;
  String? _emailError;
  String? _passError;

  late AnimationController _entranceCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  late AnimationController _stepCtrl;
  late Animation<double> _stepFade;
  late Animation<Offset> _stepSlide;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..value = 1.0;
    _stepFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut));
    _stepSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
            CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _stepCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Check email with Firebase Auth directly ────────────
  Future<void> _handleEmailContinue() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _emailError = null;
      _loading = true;
    });

    try {
      // ✅ Ask Firebase Auth directly — 100% reliable
      final status = await _auth.checkEmail(email);

      await _stepCtrl.reverse();
      setState(() {
        _step = 1;
        _isNewUser = status == EmailStatus.newUser;
        _passError = null;
      });
      await _stepCtrl.forward();
    } on AuthException catch (e) {
      setState(() => _emailError = e.message);
    } catch (_) {
      setState(() => _emailError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 2: Sign up or sign in ─────────────────────────────────
  Future<void> _handlePasswordContinue() async {
    // Validate name for new users
    if (_isNewUser && _nameCtrl.text.trim().isEmpty) {
      setState(() => _passError = 'Please enter your full name.');
      return;
    }
    // Validate password length
    if (_passCtrl.text.length < 6) {
      setState(() => _passError = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _passError = null;
      _loading = true;
    });

    try {
      if (_isNewUser) {
        // New user — register
        await _auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          name: _nameCtrl.text.trim(),
        );
      } else {
        // Existing user — sign in
        await _auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            _smoothRoute(const DashboardScreen()), (_) => false);
      }
    } on AuthException catch (e) {
      setState(() => _passError = e.message);
    } catch (_) {
      setState(
              () => _passError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Forgot Password ────────────────────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _resetLoading = true);

    try {
      await _auth.sendPasswordReset(email);
      if (mounted) {
        _snack('✅ Password reset email sent to $email. Check your inbox.');
      }
    } on AuthException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Failed to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  // ── Google ─────────────────────────────────────────────────────
  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final result = await _auth.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            _smoothRoute(const DashboardScreen()), (_) => false);
      }
    } on AuthException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _handleApple() => _snack('Apple Sign-In coming soon.');

  // ── Back to email step ─────────────────────────────────────────
  Future<void> _backToEmail() async {
    await _stepCtrl.reverse();
    setState(() {
      _step = 0;
      _passCtrl.clear();
      _nameCtrl.clear();
      _passError = null;
    });
    await _stepCtrl.forward();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFF2D2D2D),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDark.bg,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _step == 1
                          ? _CircleBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          onTap: _backToEmail)
                          : const SizedBox(width: 36),
                      _CircleBtn(
                          icon: Icons.close_rounded,
                          size: 18,
                          onTap: () => Navigator.pop(context)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        const Text('IELTS AI',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 20),

                        // Animated step content
                        FadeTransition(
                          opacity: _stepFade,
                          child: SlideTransition(
                            position: _stepSlide,
                            child: _step == 0
                                ? _buildEmailStep()
                                : _buildPasswordStep(),
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
      ),
    );
  }

  // ── Email Step ─────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Column(
      children: [
        const Text('Log in or sign up',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -1.0,
                height: 1.1)),
        const SizedBox(height: 8),
        Text('New users are registered automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
                height: 1.5)),
        const SizedBox(height: 36),

        _InputField(
          controller: _emailCtrl,
          hint: 'Email address',
          keyboardType: TextInputType.emailAddress,
          error: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        const SizedBox(height: 10),

        _ActionButton(
          onTap: _handleEmailContinue,
          isLoading: _loading,
          label: 'Continue',
          bgColor: Colors.white,
          textColor: Colors.black,
        ),

        const SizedBox(height: 24),
        _OrDivider(),
        const SizedBox(height: 20),

        _ActionButton(
          onTap: _handleGoogle,
          isLoading: _googleLoading,
          label: 'Continue with Google',
          bgColor: AppDark.surface2,
          textColor: Colors.white,
          borderColor: AppDark.border,
          icon: _GoogleLogo(),
        ),
        const SizedBox(height: 10),

        _ActionButton(
          onTap: _handleApple,
          isLoading: false,
          label: 'Continue with Apple',
          bgColor: AppDark.surface2,
          textColor: Colors.white,
          borderColor: AppDark.border,
          icon: const Icon(Icons.apple, color: Colors.white, size: 20),
        ),

        const SizedBox(height: 32),
        Text('Terms of Use  ·  Privacy Policy',
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.25),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.2))),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Password Step ──────────────────────────────────────────────
  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNewUser ? 'Create account' : 'Welcome back',
          style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.1),
        ),

        const SizedBox(height: 14),

        // Email chip
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppDark.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppDark.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline_rounded,
                  size: 14, color: Colors.white.withOpacity(0.45)),
              const SizedBox(width: 6),
              Text(_emailCtrl.text.trim(),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Name field — new users only
        if (_isNewUser) ...[
          _InputField(
            controller: _nameCtrl,
            hint: 'Full name',
            keyboardType: TextInputType.name,
            error: null,
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
        ],

        // Password field
        _InputField(
          controller: _passCtrl,
          hint: _isNewUser ? 'Create a password' : 'Password',
          keyboardType: TextInputType.visiblePassword,
          obscureText: _obscurePass,
          error: _passError,
          onChanged: (_) {
            if (_passError != null) setState(() => _passError = null);
          },
          showSuffix: true,
          suffixVisible: _obscurePass,
          onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
        ),

        // Forgot password — existing users only
        if (!_isNewUser) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _resetLoading ? null : _handleForgotPassword,
              child: _resetLoading
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white38))
                  : Text('Forgot password?',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      decoration: TextDecoration.underline,
                      decorationColor:
                      Colors.white.withOpacity(0.3))),
            ),
          ),
        ],

        const SizedBox(height: 20),

        _ActionButton(
          onTap: _handlePasswordContinue,
          isLoading: _loading,
          label: _isNewUser ? 'Create Account' : 'Sign In',
          bgColor: Colors.white,
          textColor: Colors.black,
        ),

        if (_isNewUser) ...[
          const SizedBox(height: 14),
          Text(
            'By creating an account you agree to our\nTerms of Use and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.3),
                height: 1.6),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: AppDark.surface2, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white54, size: size),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: Colors.white.withOpacity(0.12), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: 1)),
        ),
        Expanded(
            child: Divider(
                color: Colors.white.withOpacity(0.12), thickness: 1)),
      ],
    );
  }
}

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final String? error;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final VoidCallback? onSuffixTap;
  final bool showSuffix;
  final bool suffixVisible;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.error,
    required this.onChanged,
    this.obscureText = false,
    this.onSuffixTap,
    this.showSuffix = false,
    this.suffixVisible = true,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppDark.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.error != null
                    ? Colors.redAccent.withOpacity(0.8)
                    : _focused
                    ? Colors.white.withOpacity(0.5)
                    : AppDark.border,
                width: _focused || widget.error != null ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboardType,
              obscureText: widget.obscureText,
              onChanged: widget.onChanged,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 17),
                suffixIcon: widget.showSuffix
                    ? GestureDetector(
                  onTap: widget.onSuffixTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      widget.suffixVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: Colors.white38,
                    ),
                  ),
                )
                    : null,
                suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.error_outline_rounded,
                size: 13, color: Colors.redAccent),
            const SizedBox(width: 5),
            Expanded(
                child: Text(widget.error!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w400))),
          ]),
        ],
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Widget? icon;

  const _ActionButton({
    required this.onTap,
    required this.isLoading,
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.borderColor = Colors.transparent,
    this.icon,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _p;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _p = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _s = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _p, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _p.forward(),
      onTapUp: (_) {
        _p.reverse();
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => _p.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.borderColor),
          ),
          child: widget.isLoading
              ? Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.textColor)))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 10),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 20, height: 20, child: CustomPaint(painter: _GLogoPainter()));
  }
}

class _GLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final sw = size.width * 0.2;
    final rect = Rect.fromCircle(center: c, radius: r - sw / 2);
    void arc(double start, double sweep, Color color) {
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..color = color
            ..strokeWidth = sw
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt);
    }

    const pi = math.pi;
    arc(-pi / 4, pi / 2 + pi / 4, const Color(0xFF4285F4));
    arc(pi / 4, pi / 2, const Color(0xFF34A853));
    arc(3 * pi / 4, pi / 2, const Color(0xFFFBBC05));
    arc(5 * pi / 4, pi / 2 + pi / 4, const Color(0xFFEA4335));
    canvas.drawLine(
        Offset(c.dx, c.dy),
        Offset(c.dx + r - sw / 2, c.dy),
        Paint()
          ..color = const Color(0xFF4285F4)
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_) => false;
}

Route _smoothRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, __, child) {
      final c =
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position:
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(c),
          child: child,
        ),
      );
    },
  );
}