import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../models/workout.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_theme.dart';
import 'setting_screen.dart';
import 'edit_profile_screen.dart';
import 'body_stats_screen.dart';
import '../../bloc/body_stats/body_stats_bloc.dart';
import '../../bloc/edit_profile/edit_profile_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../../social/presentation/screens/social_screen.dart';
import '../../../social/bloc/social_network/social_network_bloc.dart';
import '../../../../widgets/feed_post_card.dart';
import '../../../../utils/responsive.dart';
import '../../bloc/profile_bloc.dart';
import '../../bloc/profile_event.dart';
import '../../bloc/profile_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileBloc _bloc;

  static Color get primaryColor => AppTheme.accent;

  @override
  void initState() {
    super.initState();
    _bloc = ProfileBloc()..add(const ProfileLoadRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _goToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true) {
      _bloc.add(const ProfileLoadRequested());
    }
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<SettingsBloc>(
          create: (_) => SettingsBloc(),
          child: const SettingScreen(),
        ),
      ),
    );
  }

  double _calculateBMI(Map<String, dynamic> profile) {
    final height = (profile[ProfileService.keyHeight] as num?)?.toDouble() ?? 0.0;
    final weight = (profile[ProfileService.keyWeight] as num?)?.toDouble() ?? 0.0;
    if (height > 0 && weight > 0) {
      final h = height / 100;
      return weight / (h * h);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state.isLoading) {
            return Scaffold(
              backgroundColor: AppTheme.surface,
              body: Center(child: CircularProgressIndicator(color: primaryColor)),
            );
          }

          final username = state.profile[ProfileService.keyUsername] ?? '';
          final displayName = state.profile[ProfileService.keyName] ?? 'Atlet Elit';
          final bio = state.profile[ProfileService.keyStatus] ?? '';
          final goal = state.profile[ProfileService.keyGoal] ?? 'Bulking';
          final photoUrl = state.profile['photoUrl'] as String?;
          final bmi = _calculateBMI(state.profile);

          String bmiStr = bmi > 0 ? bmi.toStringAsFixed(1) : '-';
          String bmiStatus = ProfileService.getBMIStatus(bmi);

          return Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: context.fontXL * 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: context.spaceSM),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: context.fontSM,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
                  onPressed: _goToSettings,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<ProfileBloc>().add(ProfileRefreshRequested());
              },
              color: primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: context.spaceLG),

                          // Profile Header Section
                          Row(
                            children: [
                              // Photo
                              GestureDetector(
                                onTap: _goToEditProfile,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: context.avatarLG * 1.5,
                                      height: context.avatarLG * 1.5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.surfaceVariant, width: 4),
                                      ),
                                      child: ClipOval(
                                        child: (photoUrl != null && photoUrl.isNotEmpty)
                                            ? Image.network(photoUrl, fit: BoxFit.cover)
                                            : Container(
                                                color: AppTheme.surfaceVariant,
                                                child: Icon(Icons.person, size: context.iconLG * 1.5, color: AppTheme.textMuted),
                                              ),
                                      ),
                                    ),
                                    Container(
                                      width: context.spaceXL,
                                      height: context.spaceXL,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.surface, width: 2),
                                      ),
                                      child: Icon(Icons.photo_camera, color: Colors.white, size: context.iconSM * 0.7),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: context.spaceLG),

                              // Stats
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final uname = state.profile[ProfileService.keyUsername] ?? state.profile[ProfileService.keyName] ?? 'user';
                                          await Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => BlocProvider<SocialNetworkBloc>(
                                              create: (_) => SocialNetworkBloc(),
                                              child: SocialScreen(initialTab: 'followers', username: uname, uid: AuthService.uid),
                                            )
                                          ));
                                          context.read<ProfileBloc>().add(const ProfileLoadRequested());
                                        },
                                        child: _buildStatColumn(state.followersCount.toString(), 'Pengikut'),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final uname = state.profile[ProfileService.keyUsername] ?? state.profile[ProfileService.keyName] ?? 'user';
                                          await Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => BlocProvider<SocialNetworkBloc>(
                                              create: (_) => SocialNetworkBloc(),
                                              child: SocialScreen(initialTab: 'following', username: uname, uid: AuthService.uid),
                                            )
                                          ));
                                          context.read<ProfileBloc>().add(const ProfileLoadRequested());
                                        },
                                        child: _buildStatColumn(state.followingCount.toString(), 'Mengikuti'),
                                      ),
                                    ),
                                    Expanded(child: _buildStatColumn(state.activitiesCount.toString(), 'Aktivitas')),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Bio Section
                          Text(
                            displayName,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bio.isNotEmpty ? '$bio • $goal Goal' : '$goal Goal',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // BMI Badge
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BlocProvider<BodyStatsBloc>(
                                    create: (context) => BodyStatsBloc(),
                                    child: const BodyStatsScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monitor_weight_rounded, color: AppTheme.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'BMI $bmiStr $bmiStatus',
                                    style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _goToEditProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.textPrimary, // Graphite
                                foregroundColor: AppTheme.surface,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Edit Profil',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),

                  // Feed Content
                  _buildListFeed(context, state),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildListFeed(BuildContext context, ProfileState state) {
    if (state.userPosts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('Belum ada aktivitas olahraga.', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: state.userPosts.length,
      itemBuilder: (context, index) {
        return FeedPostCard(
          post: state.userPosts[index],
          onDataChanged: () => context.read<ProfileBloc>().add(const ProfileLoadRequested(silent: true)),
        );
      },
    );
  }
}
