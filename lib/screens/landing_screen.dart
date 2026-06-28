import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoadingLogin = false;
  bool _isLoadingRegister = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LOGIN: Google Sign-In â†’ cek Firestore â†’ masuk jika terdaftar
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _handleLogin() async {
    if (_isLoadingLogin || _isLoadingRegister) return;
    setState(() => _isLoadingLogin = true);

    try {
      final user = await AuthService.signInWithGoogle();

      if (!mounted) return;

      if (user == null) {
        // User membatalkan Google Sign-In
        setState(() => _isLoadingLogin = false);
        return;
      }

      // Cek apakah akun sudah terdaftar di Firestore
      final exists = await AuthService.checkUserExistsInCloud();

      if (!mounted) return;

      if (exists) {
        // âœ… Terdaftar â€” restore semua data dari Firestore ke SQLite SEBELUM navigasi
        // Di-await agar SQLite sudah terisi saat screen pertama kali dibuka
        print('[LandingScreen] Memulihkan data dari Firestore...');
        try {
          await CloudSyncService.restoreAllFromCloud();
        } catch (e) {
          print('[LandingScreen] Restore gagal (mungkin offline): $e');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        // âŒ Belum terdaftar â€” sign out, arahkan untuk register
        await AuthService.signOut();
        if (!mounted) return;
        setState(() => _isLoadingLogin = false);
        _showSnackbar(
          'Akun belum terdaftar. Silakan Register terlebih dahulu.',
          AppTheme.accentOrange,
          icon: Icons.person_add_alt_1_rounded,
        );
      }
    } catch (e) {
      print('[LandingScreen] Login error: $e');
      await AuthService.signOut();
      if (mounted) setState(() => _isLoadingLogin = false);
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // REGISTER: Google Sign-In â†’ cek Firestore â†’ onboarding jika belum ada
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _handleRegister() async {
    if (_isLoadingLogin || _isLoadingRegister) return;
    setState(() => _isLoadingRegister = true);

    try {
      final user = await AuthService.signInWithGoogle();

      if (!mounted) return;

      if (user == null) {
        setState(() => _isLoadingRegister = false);
        return;
      }

      // Cek apakah akun sudah terdaftar
      final exists = await AuthService.checkUserExistsInCloud();

      if (!mounted) return;

      if (exists) {
        // âŒ Sudah terdaftar â€” arahkan untuk login
        await AuthService.signOut();
        if (!mounted) return;
        setState(() => _isLoadingRegister = false);
        _showSnackbar(
          'Akun sudah terdaftar. Silakan Login.',
          AppTheme.electricBlue,
          icon: Icons.login_rounded,
        );
      } else {
        // âœ… Belum terdaftar â€” lanjut ke onboarding
        // Bersihkan data lokal lama sebelum mulai fresh
        await AuthService.clearLocalSession();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      print('[LandingScreen] Register error: $e');
      await AuthService.signOut();
      if (mounted) setState(() => _isLoadingRegister = false);
    }
  }

  void _showSnackbar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BUILD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface, // Paper White
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScrollConfiguration(
              behavior: const _GlowScrollBehavior(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                  // â”€â”€ Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26), // radius-3xl
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5406).withOpacity(0.15), // Ember orange soft glow
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset('assets/icons/logo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(height: 48),

                  // â”€â”€ App Name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Capai Target ',
                          style: TextStyle(
                            color: const Color(0xFF00B33F), // Verdant Green
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'bersama Kora',
                          style: TextStyle(
                            color: AppTheme.textPrimary, // Graphite
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Asisten Digital untuk Atlet\nLacak latihan, nutrisi, dan jadwalmu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // â”€â”€ Register Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoadingLogin || _isLoadingRegister)
                          ? null
                          : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5406), // Ember Orange
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26), // radius-3xl
                        ),
                      ),
                      child: _isLoadingRegister
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleGIcon(),
                                SizedBox(width: 16),
                                Text(
                                  'Daftar dengan Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600, // DemiBold
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // â”€â”€ Login Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: (_isLoadingLogin || _isLoadingRegister)
                          ? null
                          : _handleLogin,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceVariant, // Fog
                        foregroundColor: AppTheme.textPrimary, // Graphite
                        elevation: 0,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26), // radius-3xl
                        ),
                      ),
                      child: _isLoadingLogin
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: const Color(0xFFFF5406),
                                  strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleGIcon(),
                                SizedBox(width: 16),
                                Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // â”€â”€ Terms â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Text(
                    'Dengan mendaftar, Anda menyetujui\nKetentuan Layanan & Kebijakan Privasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          const Color(0xFF72A2C5), // Mist Blue for muted text
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget Google "G" icon kecil
class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/kora_logo.svg', // using the SVG provided by the user
      width: 22,
      height: 22,
    );
  }
}

class _GlowScrollBehavior extends ScrollBehavior {
  const _GlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: const Color(0xFFFF5406).withOpacity(0.3), // Orange tema Kora
      child: child,
    );
  }
}
