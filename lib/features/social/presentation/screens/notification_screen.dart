import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../theme/app_theme.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../profile/bloc/public_profile/public_profile_bloc.dart';
import '../../bloc/notification/notification_bloc.dart';
import '../../bloc/notification/notification_event.dart';
import '../../bloc/notification/notification_state.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(LoadNotifications());
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  Widget _buildAvatar(String? photoUrl, String type) {
    // Default system/reminder icon
    IconData iconData = Icons.notifications;
    Color iconColor = AppTheme.textPrimary;
    Color bgColor = AppTheme.surfaceVariant;
    
    if (type == 'follow') {
      iconData = Icons.person_add;
      iconColor = const Color(0xFF0099F9); // pending-blue
      bgColor = const Color(0xFF0099F9).withOpacity(0.1);
    } else if (type == 'reminder') {
      iconData = Icons.alarm;
      iconColor = AppTheme.accent; // ember-orange
      bgColor = AppTheme.accent.withOpacity(0.1);
    } else if (type == 'like') {
      iconData = Icons.favorite;
      iconColor = const Color(0xFFFF3400); // red
      bgColor = const Color(0xFFFF3400).withOpacity(0.1);
    } else if (type == 'comment') {
      iconData = Icons.mode_comment;
      iconColor = const Color(0xFFBD4BE5); // purple
      bgColor = const Color(0xFFBD4BE5).withOpacity(0.1);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor),
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
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: BlocConsumer<NotificationBloc, NotificationState>(
        listener: (context, state) {
          if (state.status == NotificationStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.accentRed,
            ));
          }
        },
        builder: (context, state) {
          if (state.status == NotificationStatus.loading || state.status == NotificationStatus.initial) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          
          if (state.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Belum ada notifikasi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.notifications.length,
            separatorBuilder: (context, index) => Divider(color: AppTheme.border, height: 1),
            itemBuilder: (context, index) {
              final notif = state.notifications[index];
              final isRead = notif['isRead'] ?? true;
              final type = notif['type'] as String? ?? '';
              final relatedUid = notif['relatedUid'] as String?;
              
              return GestureDetector(
                onTap: () {
                  if (type == 'follow' && relatedUid != null && relatedUid.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider<PublicProfileBloc>(
                          create: (_) => PublicProfileBloc(),
                          child: PublicProfileScreen(uid: relatedUid),
                        ),
                      ),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: isRead ? Colors.transparent : AppTheme.accent.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(notif['relatedPhotoUrl'] as String?, type),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'] ?? 'Info Kora',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['body'] ?? '',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatTimestamp(notif['timestamp'] as Timestamp?),
                              style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
