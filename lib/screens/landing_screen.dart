import 'package:flutter/material.dart';
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

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN: Google Sign-In → cek Firestore → masuk jika terdaftar
  // ─────────────────────────────────────────────────────────────────────────
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
        // ✅ Terdaftar — restore profil dari cloud lalu masuk
        // Jika SQLite lokal kosong (device baru), restore semua data dari Firestore
        final isEmpty = await CloudSyncService.isLocalDataEmpty();
        if (isEmpty) {
          print('[LandingScreen] SQLite kosong, restore data dari Firestore...');
          // Restore di background, tidak perlu tunggu selesai untuk masuk app
          CloudSyncService.restoreAllFromCloud().catchError((_) {});
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        // ❌ Belum terdaftar — sign out, arahkan untuk register
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

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER: Google Sign-In → cek Firestore → onboarding jika belum ada
  // ─────────────────────────────────────────────────────────────────────────
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
        // ❌ Sudah terdaftar — arahkan untuk login
        await AuthService.signOut();
        if (!mounted) return;
        setState(() => _isLoadingRegister = false);
        _showSnackbar(
          'Akun sudah terdaftar. Silakan Login.',
          AppTheme.electricBlue,
          icon: Icons.login_rounded,
        );
      } else {
        // ✅ Belum terdaftar — lanjut ke onboarding
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo ─────────────────────────────────────────────
                  Container(
                    width: context.avatarLG,
                    height: context.avatarLG,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.radiusLG),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF093247).withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.radiusLG),
                      child: Image.asset('assets/icons/logo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(height: context.space2XL),

                  // ── App Name ─────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.neonGreenGrad.createShader(bounds),
                    child: Text(
                      'Kora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.font3XL,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: context.spaceMD),
                  Text(
                    'Asisten Digital untuk Atlet\nLacak latihan, nutrisi, dan jadwalmu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: context.fontBase,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Feature list ─────────────────────────────────────
                  _buildFeatureRow(Icons.directions_run_rounded,
                      'Lacak aktivitas lari & angkat beban'),
                  SizedBox(height: context.spaceMD),
                  _buildFeatureRow(
                      Icons.restaurant_rounded, 'Monitor asupan nutrisi harian'),
                  SizedBox(height: context.spaceMD),
                  _buildFeatureRow(
                      Icons.calendar_month_rounded, 'Atur jadwal latihan'),
                  SizedBox(height: context.spaceMD),
                  _buildFeatureRow(Icons.cloud_sync_rounded,
                      'Data tersimpan di cloud, aman di semua perangkat'),

                  const Spacer(flex: 2),

                  // ── Register Button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: context.buttonHeight,
                    child: ElevatedButton(
                      onPressed:
                          (_isLoadingLogin || _isLoadingRegister) ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radiusLG),
                        ),
                      ),
                      child: _isLoadingRegister
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleGIcon(),
                                SizedBox(width: context.spaceMD),
                                Text(
                                  'Daftar dengan Google',
                                  style: TextStyle(
                                    fontSize: context.fontMD,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: context.spaceMD),

                  // ── Login Button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: context.buttonHeight,
                    child: OutlinedButton(
                      onPressed:
                          (_isLoadingLogin || _isLoadingRegister) ? null : _handleLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 0,
                        side: BorderSide(color: AppTheme.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radiusLG),
                        ),
                      ),
                      child: _isLoadingLogin
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: AppTheme.neonGreen, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleGIcon(),
                                SizedBox(width: context.spaceMD),
                                Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontSize: context.fontMD,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: context.spaceLG),

                  // ── Terms ─────────────────────────────────────────────
                  Text(
                    'Dengan mendaftar, Anda menyetujui\nKetentuan Layanan & Kebijakan Privasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: context.fontXS,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: context.spaceLG),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: context.avatarSM,
          height: context.avatarSM,
          decoration: BoxDecoration(
            color: AppTheme.neonGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(context.radiusSM),
          ),
          child: Icon(icon, color: AppTheme.neonGreen, size: context.iconSM),
        ),
        SizedBox(width: context.spaceLG),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: context.fontSM,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget Google "G" icon kecil
class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.blue[700],
          ),
        ),
      ),
    );
  }
}
