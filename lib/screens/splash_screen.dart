import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;

  // Subtle floating animation for logo
  late AnimationController _floatCtrl;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));

    _textFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOut)));
    _textSlide = Tween<Offset>(
        begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic)));

    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.62, 0.9, curve: Curves.easeOut)));
    _btnSlide = Tween<Offset>(
        begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.62, 0.9, curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, animation, __) => AuthScreen(),
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, animation, __, child) {
        final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position:
            Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo with float
              AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _floatCtrl]),
                builder: (_, __) => FadeTransition(
                  opacity: _logoFade,
                  child: Transform.translate(
                    offset: Offset(0, -_float.value),
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 32,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('IE',
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Title + subtitle
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(position: _textSlide, child: child),
                ),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(children: [
                        TextSpan(
                            text: 'Ace Your\n',
                            style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -1.8,
                                height: 1.1)),
                        TextSpan(
                            text: 'IELTS Exam',
                            style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                letterSpacing: -1.8,
                                height: 1.2)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'AI-powered preparation that\nadapts to your level.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.6),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Button
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => FadeTransition(
                  opacity: _btnFade,
                  child: SlideTransition(position: _btnSlide, child: child),
                ),
                child: Column(
                  children: [
                    _GetStartedBtn(onTap: _goToAuth),
                    const SizedBox(height: 14),
                    Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _GetStartedBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _GetStartedBtn({required this.onTap});

  @override
  State<_GetStartedBtn> createState() => _GetStartedBtnState();
}

class _GetStartedBtnState extends State<_GetStartedBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _p;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _p = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _s = Tween<double>(begin: 1.0, end: 0.96)
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
        widget.onTap();
      },
      onTapCancel: () => _p.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Get Started',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}