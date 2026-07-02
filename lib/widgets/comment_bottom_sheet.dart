import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;

  const CommentBottomSheet({super.key, required this.postId});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await SocialService.getComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    await SocialService.addComment(widget.postId, text);
    _commentCtrl.clear();
    await _loadComments();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd MMM • HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spaceXL, vertical: context.spaceSM),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Komentar',
                style: TextStyle(
                  fontSize: context.fontLG,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.surfaceVariant),
          
          Expanded(
            child: _isLoading && _comments.isEmpty
                ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _comments.isEmpty
                    ? Center(child: Text('Belum ada komentar', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: context.spaceXL, vertical: context.spaceLG),
                        itemCount: _comments.length,
                        itemBuilder: (context, i) {
                          final c = _comments[i];
                          final photoUrl = c['authorPhotoUrl'];
                          return Padding(
                            padding: EdgeInsets.only(bottom: context.spaceLG),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: context.avatarSM,
                                  height: context.avatarSM,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.surfaceVariant,
                                  ),
                                  child: ClipOval(
                                    child: (photoUrl != null && photoUrl.isNotEmpty)
                                        ? Image.network(photoUrl, fit: BoxFit.cover)
                                        : Icon(Icons.person, size: context.iconSM, color: AppTheme.textMuted),
                                  ),
                                ),
                                SizedBox(width: context.spaceMD),
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(context.spaceMD),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              c['authorName'] ?? 'Anon',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.fontSM, color: AppTheme.textPrimary),
                                            ),
                                            Text(
                                              _formatTime(c['timestamp']),
                                              style: TextStyle(fontSize: context.fontXS, color: AppTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: context.spaceXS),
                                        Text(
                                          c['text'] ?? '',
                                          style: TextStyle(fontSize: context.fontBase, color: AppTheme.textPrimary, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          
          // Input field
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.spaceXL, vertical: context.spaceLG),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: TextStyle(fontSize: context.fontBase),
                    decoration: InputDecoration(
                      hintText: 'Tulis komentar...',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceLG, vertical: context.spaceMD),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.spaceMD),
                GestureDetector(
                  onTap: _submitComment,
                  child: Container(
                    width: context.buttonHeight * 0.9, height: context.buttonHeight * 0.9,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading && _comments.isNotEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded, color: Colors.white, size: context.iconSM),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
