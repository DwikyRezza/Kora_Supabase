import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../social/presentation/screens/social_screen.dart';
import '../../../social/bloc/social_network/social_network_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/feed_post_card.dart';
import '../../bloc/public_profile/public_profile_bloc.dart';
import '../../bloc/public_profile/public_profile_event.dart';
import '../../bloc/public_profile/public_profile_state.dart';

class PublicProfileScreen extends StatefulWidget {
  final String uid;

  const PublicProfileScreen({super.key, required this.uid});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PublicProfileBloc>().add(LoadPublicProfile(widget.uid));
  }

  Future<void> _refreshData() async {
    context.read<PublicProfileBloc>().add(LoadPublicProfile(widget.uid, silent: true));
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        return ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.person, size: 48, color: AppTheme.textMuted)));
      } catch (_) {}
    }
    return Icon(Icons.person, size: 48, color: AppTheme.textMuted);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PublicProfileBloc, PublicProfileState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppTheme.accent,
          ));
        }
      },
      builder: (context, state) {
        if (state.status == PublicProfileStatus.loading) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, iconTheme: IconThemeData(color: AppTheme.textPrimary)),
            body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          );
        }

        if (state.status == PublicProfileStatus.failure && state.userProfile == null) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, iconTheme: IconThemeData(color: AppTheme.textPrimary)),
            body: Center(child: Text('Pengguna tidak ditemukan', style: TextStyle(color: AppTheme.textMuted))),
          );
        }
        
        if (state.userProfile == null) {
            return Scaffold(
              backgroundColor: AppTheme.surface,
              appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, iconTheme: IconThemeData(color: AppTheme.textPrimary)),
              body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            );
        }

        final name = state.userProfile!['name'] ?? 'Athlete';
        final username = state.userProfile!['username'] ?? '';
        final photoUrl = state.userProfile!['photoUrl'];

        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: AppTheme.textPrimary),
            title: Text(username.isNotEmpty ? '@$username' : name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.surfaceVariant,
                              ),
                              child: _buildAvatar(photoUrl),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => BlocProvider<SocialNetworkBloc>(
                                        create: (_) => SocialNetworkBloc(),
                                        child: SocialScreen(initialTab: 'followers', username: username, uid: widget.uid),
                                      )
                                    ));
                                  },
                                  child: _buildStat('Pengikut', state.followersCount),
                                ),
                                Container(width: 1, height: 24, color: AppTheme.surfaceVariant),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => BlocProvider<SocialNetworkBloc>(
                                        create: (_) => SocialNetworkBloc(),
                                        child: SocialScreen(initialTab: 'following', username: username, uid: widget.uid),
                                      )
                                    ));
                                  },
                                  child: _buildStat('Mengikuti', state.followingCount),
                                ),
                                Container(width: 1, height: 24, color: AppTheme.surfaceVariant),
                                _buildStat('Aktivitas', state.userPosts.length),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (!state.isMe)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: state.isProcessingFollow ? null : () {
                                    context.read<PublicProfileBloc>().add(ToggleFollow(widget.uid));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: state.isFollowing ? AppTheme.surfaceVariant : AppTheme.accent,
                                    foregroundColor: state.isFollowing ? AppTheme.textPrimary : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: state.isFollowing ? BorderSide(color: AppTheme.border) : BorderSide.none,
                                    ),
                                  ),
                                  child: state.isProcessingFollow
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(
                                          state.isFollowing ? 'Mengikuti' : 'Ikuti',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 32, thickness: 8, color: AppTheme.surfaceVariant),
                    ],
                  ),
                ),
                if (state.userPosts.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text('Belum ada aktivitas yang dibagikan.', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: state.userPosts.length,
                    itemBuilder: (context, index) {
                      return FeedPostCard(
                        post: state.userPosts[index],
                        onDataChanged: _refreshData,
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
