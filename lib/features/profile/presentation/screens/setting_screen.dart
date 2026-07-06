import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../../../screens/landing_screen.dart';
import '../../../../screens/qna_screen.dart';
import 'edit_profile_screen.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/settings/settings_event.dart';
import '../../bloc/settings/settings_state.dart';
import '../../bloc/edit_profile/edit_profile_bloc.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(LoadSettings());
  }

  void _signOut() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Keluar'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) {
        context.read<SettingsBloc>().add(SignOutRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppTheme.accent,
          ));
        }
        if (state.isSignOutSuccess) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LandingScreen()),
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.accentOrange),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Pengaturan',
              style: TextStyle(
                color: AppTheme.accentOrange,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group: Akun
                    _buildSectionTitle('AKUN'),
                    const SizedBox(height: 16),
                    _buildContainer([
                      _buildListItem(
                        icon: Icons.ads_click_rounded,
                        title: 'Target',
                        iconColor: AppTheme.accentOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider<EditProfileBloc>(
                                create: (_) => EditProfileBloc(),
                                child: const EditProfileScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // Group: Aplikasi
                    _buildSectionTitle('APLIKASI'),
                    const SizedBox(height: 16),
                    _buildContainer([
                      _buildSwitchItem(
                        icon: Icons.notifications_rounded,
                        title: 'Notifikasi',
                        value: state.notifEnabled,
                        onChanged: (val) => context.read<SettingsBloc>().add(ToggleNotification(val)),
                        iconColor: AppTheme.accentOrange,
                      ),
                      _buildDivider(),
                      _buildSwitchItem(
                        icon: state.darkMode
                            ? Icons.nights_stay_rounded
                            : Icons.wb_sunny_rounded,
                        title: 'Mode',
                        value: state.darkMode,
                        onChanged: (val) => context.read<SettingsBloc>().add(ToggleDarkMode(val)),
                        iconColor: AppTheme.accentOrange,
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // Group: Bantuan
                    _buildSectionTitle('BANTUAN'),
                    const SizedBox(height: 16),
                    _buildContainer([
                      _buildListItem(
                        icon: Icons.help_outline_rounded,
                        title: 'Tanya Jawab (Q&A)',
                        iconColor: AppTheme.accentOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QnaScreen()),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),

                    // Group: Zona Bahaya
                    _buildSectionTitle('ZONA BAHAYA', color: errorColor),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        children: [
                          _buildListItem(
                            icon: Icons.logout_rounded,
                            title: 'Keluar dari Akun',
                            titleColor: errorColor,
                            iconColor: errorColor,
                            showChevron: false,
                            onTap: _signOut,
                          ),
                          Divider(color: errorColor.withOpacity(0.1), height: 1),
                          _buildListItem(
                            icon: Icons.delete_forever_rounded,
                            title: 'Hapus Akun',
                            titleColor: AppTheme.textMuted,
                            iconColor: AppTheme.textMuted,
                            showChevron: false,
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hapus Akun'),
                                  content: const Text(
                                      'Apakah Anda yakin ingin menghapus akun secara permanen? Tindakan ini tidak dapat dibatalkan.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Batal')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: errorColor),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Permintaan hapus akun diterima. Fitur ini masih dalam tahap pengembangan.')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isSigningOut)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? AppTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(color: AppTheme.border.withOpacity(0.3), height: 1);
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Color? iconColor,
    Color? titleColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppTheme.accentOrange, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              if (trailingText != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      trailingText,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              if (showChevron)
                Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppTheme.accentOrange, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.accentOrange,
            inactiveTrackColor: AppTheme.surfaceVariant,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
