import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/public_profile_screen.dart';
import 'comment_bottom_sheet.dart';

class FeedPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onDataChanged;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onDataChanged,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;
  
  String _authorName = 'Athlete';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _initData();
    }
  }

  void _initData() {
    final likedBy = widget.post['likedBy'] as List<dynamic>? ?? [];
    final currentUid = AuthService.uid;
    _isLiked = likedBy.contains(currentUid);
    _likesCount = likedBy.length;
    _commentsCount = widget.post['commentsCount'] as int? ?? 0;
    
    _authorName = widget.post['authorName'] ?? 'Athlete';
    _photoUrl = widget.post['authorPhotoUrl'];
    
    _fetchLatestProfile();
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final uid = widget.post['uid'] as String?;
      if (uid == null) return;
      
      final profile = await SocialService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          _authorName = profile['name'] ?? _authorName;
          _photoUrl = profile['photoUrl'] ?? _photoUrl;
        });
      }
    } catch (e) {
      print('[FeedPostCard] Error fetching profile: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() {
      _isLiking = true;
      if (_isLiked) {
        _likesCount--;
      } else {
        _likesCount++;
      }
      _isLiked = !_isLiked;
    });

    final postId = widget.post['postId'] as String;
    final likedBy = widget.post['likedBy'] as List<dynamic>? ?? [];
    
    await SocialService.toggleLike(postId, likedBy);
    setState(() => _isLiking = false);
    widget.onDataChanged(); // Trigger reload di parent
  }

  void _showComments() {
    final postId = widget.post['postId'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CommentBottomSheet(postId: postId),
      ),
    ).then((_) => widget.onDataChanged());
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) return DateFormat('dd MMM yyyy').format(date);
    if (diff.inDays > 0) return '${diff.inDays} hari yang lalu';
    if (diff.inHours > 0) return '${diff.inHours} jam yang lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes} menit yang lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final workoutData = widget.post['workoutData'] as Map<String, dynamic>? ?? {};
    final type = workoutData['type'] ?? 'workout';
    final title = workoutData['title'] ?? 'Aktivitas Latihan';
    final dist = workoutData['distance'] as num? ?? 0.0;
    final dur = workoutData['duration'] as num? ?? 0.0; // minutes
    
    // Parse duration format
    final int durMin = dur.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: widget.post['uid'])),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2F2F2F), fontSize: 16)),
                      Text(_formatTime(widget.post['timestamp']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF2F2F2F))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Content
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2F2F2F))),
          const SizedBox(height: 12),
          
          Row(
            children: [
              _buildStatMetric(Icons.straighten, '${dist > 0 ? dist.toStringAsFixed(2) : '-'} km'),
              const SizedBox(width: 24),
              _buildStatMetric(Icons.timer_outlined, '$durMin mnt'),
            ],
          ),
          const SizedBox(height: 16),
          
          const Divider(color: Color(0xFFE0E0E0), height: 1),
          const SizedBox(height: 8),
          
          // Action Buttons
          Row(
            children: [
              _buildActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? const Color(0xFFFF3400) : const Color(0xFF2F2F2F),
                count: _likesCount,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF2F2F2F),
                count: _commentsCount,
                onTap: _showComments,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2F2F2F))),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required int count, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
