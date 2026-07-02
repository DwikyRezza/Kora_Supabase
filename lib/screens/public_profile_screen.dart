import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import 'social_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_post_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final String uid;

  const PublicProfileScreen({super.key, required this.uid});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isMe = false;
  bool _isProcessingFollow = false;

  @override
  void initState() {
    super.initState();
    _isMe = widget.uid == AuthService.uid;
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final profile = await SocialService.getUserProfile(widget.uid);
      final posts = await SocialService.getUserPosts(widget.uid);
      final followers = await SocialService.getFollowersCount(widget.uid);
      final following = await SocialService.getFollowingCount(widget.uid);
      
      bool isFollowing = false;
      if (!_isMe) {
        isFollowing = await SocialService.checkIsFollowing(widget.uid);
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userPosts = posts;
          _followersCount = followers;
          _followingCount = following;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        
        return ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.person, size: 48, color: AppTheme.textMuted)));
      } catch (_) {}
    }
    return Icon(Icons.person, size: 48, color: AppTheme.textMuted);
  }

  Future<void> _toggleFollow() async {
    if (_isProcessingFollow) return;
    setState(() => _isProcessingFollow = true);

    if (_isFollowing) {
      await SocialService.unfollowUser(widget.uid);
      setState(() {
        _isFollowing = false;
        _followersCount--;
      });
    } else {
      await SocialService.followUser(widget.uid);
      setState(() {
        _isFollowing = true;
        _followersCount++;
      });
    }

    setState(() => _isProcessingFollow = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, iconTheme: IconThemeData(color: AppTheme.textPrimary)),
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, iconTheme: IconThemeData(color: AppTheme.textPrimary)),
        body: Center(child: Text('Pengguna tidak ditemukan', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    final name = _userProfile!['name'] ?? 'Athlete';
    final username = _userProfile!['username'] ?? '';
    final photoUrl = _userProfile!['photoUrl'];

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
        onRefresh: _loadData,
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
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'followers', username: username, uid: widget.uid)));
                          },
                          child: _buildStat('Pengikut', _followersCount),
                        ),
                        Container(width: 1, height: 24, color: AppTheme.surfaceVariant),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'following', username: username, uid: widget.uid)));
                          },
                          child: _buildStat('Mengikuti', _followingCount),
                        ),
                        Container(width: 1, height: 24, color: AppTheme.surfaceVariant),
                        _buildStat('Aktivitas', _userPosts.length),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!_isMe)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessingFollow ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? AppTheme.surfaceVariant : AppTheme.accent,
                            foregroundColor: _isFollowing ? AppTheme.textPrimary : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: _isFollowing ? BorderSide(color: AppTheme.border) : BorderSide.none,
                            ),
                          ),
                          child: _isProcessingFollow
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _isFollowing ? 'Mengikuti' : 'Ikuti',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 32, thickness: 8, color: AppTheme.surfaceVariant),
              
              // Posts List
                ],
              ),
            ),
            if (_userPosts.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Belum ada aktivitas yang dibagikan.', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: _userPosts.length,
                itemBuilder: (context, index) {
                  return FeedPostCard(
                    post: _userPosts[index],
                    onDataChanged: () => _loadData(silent: true),
                  );
                },
              ),
            SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
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
