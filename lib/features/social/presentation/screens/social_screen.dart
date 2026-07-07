import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../profile/bloc/public_profile/public_profile_bloc.dart';
import '../../bloc/social_network/social_network_bloc.dart';
import '../../bloc/social_network/social_network_event.dart';
import '../../bloc/social_network/social_network_state.dart';

class SocialScreen extends StatefulWidget {
  final String initialTab; // 'followers' atau 'following'
  final String username;
  final String uid;
  
  const SocialScreen({
    super.key, 
    this.initialTab = 'followers',
    required this.username,
    required this.uid,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTab == 'followers' ? 0 : 1
    );
    context.read<SocialNetworkBloc>().add(LoadSocialData(widget.uid));
  }

  Future<void> _handleUnfollow(BuildContext context, String targetUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batal Mengikuti?'),
        content: const Text('Apakah Anda yakin ingin berhenti mengikuti akun ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Berhenti Mengikuti', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<SocialNetworkBloc>().add(UnfollowUserEvent(targetUid));
    }
  }

  Future<void> _handleRemoveFollower(BuildContext context, String followerUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengikut?'),
        content: const Text('Kora tidak akan memberi tahu mereka bahwa mereka telah dihapus dari pengikut Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Hapus', style: TextStyle(color: AppTheme.accentRed))),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<SocialNetworkBloc>().add(RemoveFollowerEvent(followerUid));
    }
  }

  Widget _buildUserAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(photoUrl, fit: BoxFit.cover);
    }
    return Icon(Icons.person, size: 28, color: AppTheme.textMuted);
  }

  Widget _buildUserRow(BuildContext context, Map<String, dynamic> user, bool isFollowersTab) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider<PublicProfileBloc>(
              create: (_) => PublicProfileBloc(),
              child: PublicProfileScreen(uid: user['uid']),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 2),
                color: AppTheme.surfaceVariant,
              ),
              child: ClipOval(child: _buildUserAvatar(user['photoUrl'] as String?)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? 'Athlete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user['username'] != null ? '@${user['username']}' : '@athlete',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.uid == AuthService.uid)
              isFollowersTab
                  ? ElevatedButton(
                      onPressed: () => _handleRemoveFollower(context, user['uid']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceVariant,
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      ),
                      child: const Text('Hapus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    )
                  : ElevatedButton(
                      onPressed: () => _handleUnfollow(context, user['uid']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceVariant,
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Mengikuti', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(SocialNetworkState state, bool isFollowersTab) {
    if (state.status == SocialNetworkStatus.loading || state.status == SocialNetworkStatus.initial) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    
    final users = isFollowersTab ? state.followers : state.following;

    if (users.isEmpty) {
      return Center(
        child: Text(
          isFollowersTab ? 'Belum ada pengikut.' : 'Belum mengikuti siapa pun.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: users.length,
      separatorBuilder: (context, index) => Divider(color: AppTheme.border, height: 16),
      itemBuilder: (context, index) {
        return _buildUserRow(context, users[index], isFollowersTab);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SocialNetworkBloc, SocialNetworkState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppTheme.accentRed,
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.accent),
              onPressed: () => Navigator.pop(context, true),
            ),
            title: Text(
              '@${widget.username}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: AppTheme.surface,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, spreadRadius: 1),
                      ]
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.accent,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.05),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Pengikut'),
                      Tab(text: 'Mengikuti'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(state, true),
                    _buildList(state, false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
