import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/social_service.dart';
import '../services/auth_service.dart';
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
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
        if (photoUrl.startsWith('data:image')) {
          final parts = photoUrl.split(',');
          if (parts.length > 1) {
            return ClipOval(child: Image.memory(base64Decode(parts[1]), fit: BoxFit.cover));
          }
        }
        return ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 48, color: Colors.grey)));
      } catch (_) {}
    }
    return const Icon(Icons.person, size: 48, color: Colors.grey);
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
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF2F2F2F))),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF00B33F))),
      );
    }

    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF2F2F2F))),
        body: const Center(child: Text('Pengguna tidak ditemukan', style: TextStyle(color: Colors.grey))),
      );
    }

    final name = _userProfile!['name'] ?? 'Athlete';
    final username = _userProfile!['username'] ?? '';
    final photoUrl = _userProfile!['photoUrl'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2F2F2F)),
        title: Text(username.isNotEmpty ? '@$username' : name, style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF00B33F),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
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
                        color: const Color(0xFFF5F5F5),
                      ),
                      child: _buildAvatar(photoUrl),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2F2F2F)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Pengikut', _followersCount),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        _buildStat('Mengikuti', _followingCount),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
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
                            backgroundColor: _isFollowing ? const Color(0xFFF5F5F5) : const Color(0xFF00B33F),
                            foregroundColor: _isFollowing ? const Color(0xFF2F2F2F) : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                              side: _isFollowing ? const BorderSide(color: Color(0xFFE0E0E0)) : BorderSide.none,
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
              const Divider(height: 32, thickness: 8, color: Color(0xFFF5F5F5)),
              
              // Posts List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aktivitas Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F2F2F))),
                    const SizedBox(height: 16),
                    if (_userPosts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Belum ada aktivitas yang dibagikan.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ..._userPosts.map((post) => FeedPostCard(
                            post: post,
                            onDataChanged: _loadData,
                          )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2F2F2F)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }
}
