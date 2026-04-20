import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../main.dart';
import 'onboarding_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final user = await AuthService.signInWithGoogle();

    if (!mounted) return;

    if (user != null) {
      // Check if user has completed onboarding locally
      bool isOnboarded = await ProfileService.isOnboarded();

      if (!isOnboarded) {
        // If not found locally, check if they exist in the database and sync them down
        isOnboarded = await ProfileService.checkAndSyncFromDatabase();
      }

      if (isOnboarded) {
        // Sync existing profile to database
        await ProfileService.syncToDatabase();
      }

      // ── Auto-restore semua data dari Firestore (untuk HP baru / pertama login) ──
      // Dilakukan di background agar tidak blocking navigasi
      if (!mounted) return;
      _autoRestoreFromCloud();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              isOnboarded ? const MainNavigation() : const OnboardingScreen(),
        ),
      );
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login dibatalkan atau gagal'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Restore data dari cloud secara silent di background
  Future<void> _autoRestoreFromCloud() async {
    try {
      await CloudSyncService.restoreDataFromCloud();
    } catch (e) {
      // Silent fail — tidak ganggu user
    }
  }


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

                  // App Logo
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
                      child: Image.asset(
                        'assets/icons/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: context.space2XL),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.neonGreenGrad.createShader(bounds),
                    child: Text(
                      'Corefit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.font3XL,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: context.spaceMD),

                  // Subtitle
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

                  // Features list
                  _buildFeatureRow(Icons.directions_run_rounded,
                      'Lacak aktivitas lari & angkat beban'),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                      Icons.restaurant_rounded, 'Monitor asupan nutrisi harian'),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                      Icons.calendar_month_rounded, 'Atur jadwal latihan'),
                  const SizedBox(height: 12),
                  _buildFeatureRow(Icons.insights_rounded,
                      'Analisis perkembangan tubuh'),

                  const Spacer(flex: 2),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: context.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radiusLG),
                          side: BorderSide(color: AppTheme.border, width: 1.5),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.neonGreen,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google "G" icon
                                Container(
                                  width: context.iconMD,
                                  height: context.iconMD,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: context.fontMD,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ),
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

                  const SizedBox(height: 16),

                  // Terms
                  Text(
                    'Dengan masuk, Anda menyetujui\nKetentuan Layanan & Kebijakan Privasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(flex: 1),
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
