import 'package:flutter/material.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../features/profile/presentation/screens/public_profile_screen.dart';
import '../features/profile/bloc/public_profile/public_profile_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTab == 'followers' ? 0 : 1
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (AuthService.isLoggedIn) {
      final uid = widget.uid;
      final followingData = await SocialService.getFollowing(uid);
      final followersData = await SocialService.getFollowers(uid);
      
      setState(() {
        _following = followingData;
        _followers = followersData;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnfollow(String targetUid) async {
    // Tampilkan dialog konfirmasi seperti Instagram
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

    if (confirm == true) {
      await SocialService.unfollowUser(targetUid);
      _loadData(); // Refresh list
    }
  }

  Future<void> _handleRemoveFollower(String followerUid) async {
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

    if (confirm == true) {
      await SocialService.removeFollower(followerUid);
      _loadData(); // Refresh list
    }
  }

  Widget _buildUserAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(photoUrl, fit: BoxFit.cover);
    }
    return Icon(Icons.person, size: 28, color: AppTheme.textMuted);
  }

  Widget _buildUserRow(Map<String, dynamic> user, bool isFollowersTab) {
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
                      onPressed: () => _handleRemoveFollower(user['uid']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceVariant, // Abu-abu terang (Fog)
                        foregroundColor: AppTheme.textPrimary, // Graphite
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      ),
                      child: const Text('Hapus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    )
                  : ElevatedButton(
                      onPressed: () => _handleUnfollow(user['uid']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceVariant, // Abu-abu
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

  Widget _buildList(List<Map<String, dynamic>> users, bool isFollowersTab) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    
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
        return _buildUserRow(users[index], isFollowersTab);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AppTheme.surface, // Background color of the pill
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, spreadRadius: 1),
                  ]
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppTheme.accent, // Primary
                unselectedLabelColor: AppTheme.textSecondary, // Secondary
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
                _buildList(_followers, true),
                _buildList(_following, false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
