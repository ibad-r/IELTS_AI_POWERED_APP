import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'splash_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _ctrl.reverse();
    if (!mounted) return;
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => SplashScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity:
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName?.split(' ').first ?? 'Student';
    final email = user?.email ?? '';
    final photo = user?.photoURL;

    return Scaffold(
      backgroundColor: AppDark.bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, $name 👋',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 2),
                          Text(email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.4))),
                        ],
                      ),
                      _ProfileMenu(
                          name: name,
                          email: email,
                          photoUrl: photo,
                          onSignOut: _signOut),
                    ],
                  ),

                  const Expanded(
                    child: Center(
                      child: Text('Dashboard',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
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
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onSignOut;

  const _ProfileMenu(
      {required this.name,
        required this.email,
        required this.photoUrl,
        required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      color: AppDark.surface2,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppDark.border),
      ),
      onSelected: (val) {
        if (val == 'logout') onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            children: [
              _Avatar(name: name, photoUrl: photoUrl, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4))),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Sign Out',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      child: _Avatar(name: name, photoUrl: photoUrl, size: 42),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  const _Avatar({required this.name, required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppDark.border, width: 1.5),
        image: photoUrl != null
            ? DecorationImage(
            image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
        color: photoUrl == null ? Colors.white : null,
      ),
      child: photoUrl == null
          ? Center(
          child: Text(name[0].toUpperCase(),
              style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: Colors.black)))
          : null,
    );
  }
}