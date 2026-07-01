import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/protein_entry.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/whistleblower_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import 'search_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'workout_detail_screen.dart';
import 'running_tracker_screen.dart';
import 'workout_setup_screen.dart';
import '../widgets/feed_post_card.dart';
import '../utils/responsive.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToProtein;
  final VoidCallback onGoToSchedule;
  final VoidCallback onGoToBodyStats;

  const HomeScreen({
    super.key,
    required this.onGoToWorkout,
    required this.onGoToProtein,
    required this.onGoToSchedule,
    required this.onGoToBodyStats,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  List<Workout> _todayWorkouts = [];
  List<ProteinEntry> _todayProtein = [];
  List<ScheduleEvent> _upcomingEvents = [];
  bool _isLoading = true;
  String _userName = '';
  String? _userPhotoUrl;
  double _baseTargetProtein = 0.0;
  DateTime _selectedScheduleDate = DateTime.now();
  int _unreadNotifs = 0;
  List<Map<String, dynamic>> _feedPosts = [];
  bool _isLoadingFeed = true;

  // ── Pagination state ───────────────────────────────────────────────────
  DocumentSnapshot? _lastFeedDoc;
  bool _isLoadingMore = false; // Debounce: prevent multiple simultaneous loads
  bool _hasMoreData = true;   // Flag: false when last page is empty
  late ScrollController _scrollController;

  Timer? _whistleTimer;

  double get _totalProteinToday =>
      _todayProtein.fold(0, (sum, e) => sum + e.proteinGrams);
  double get _totalProteinNeeded => _baseTargetProtein;
  int get _totalCaloriesToday =>
      _todayWorkouts.fold(0, (sum, w) => sum + w.caloriesBurned);
  int get _totalWorkoutMinutes =>
      _todayWorkouts.fold(0, (sum, w) => sum + w.duration.round());

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _whistleTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkWhistleblower();
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _whistleTimer?.cancel();
    super.dispose();
  }

  // ── Scroll listener for infinite scrolling ──────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreFeed();
    }
  }

  Future<void> _loadMoreFeed() async {
    // Debounce: skip if already loading or no more data
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await SocialService.getFeedPosts(startAfter: _lastFeedDoc);
      final newPosts = result['posts'] as List<Map<String, dynamic>>;
      final newLastDoc = result['lastDoc'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          _feedPosts.addAll(newPosts);
          _lastFeedDoc = newLastDoc;
          _hasMoreData = newPosts.isNotEmpty;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _checkWhistleblower() async {
    final now = DateTime.now();
    final events = await _db.getUpcomingEvents();
    for (var event in events) {
      if (event.status == 'pending' &&
          event.dateTime.year == now.year &&
          event.dateTime.month == now.month &&
          event.dateTime.day == now.day &&
          event.dateTime.hour == now.hour &&
          event.dateTime.minute == now.minute) {
        
        WhistleblowerService.playAlarm();
        
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                Icon(Icons.sports, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('Waktunya Action!', style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: Text(
              'Jadwal "${event.title}" telah tiba. Ayo mulai!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.vibrate();
                  WhistleblowerService.stopAlarm();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break; 
      }
    }
  }

  Future<void> _refreshData() async {
    // Reset pagination state before re-fetching from top
    _lastFeedDoc = null;
    _hasMoreData = true;
    try {
      await CloudSyncService.restoreAllFromCloud().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final today = DateTime.now();
    try {
      await _db.checkLateSchedules();
      final workouts = await _db.getWorkoutsByDate(today);
      final protein = await _db.getProteinEntriesByDate(today);
      final events = await _db.getScheduleEventsByDate(_selectedScheduleDate);
      final profile = await ProfileService.getProfile();
      final unread = await NotificationService.getUnreadCount();

      // Load first page of feed (always fresh)
      final feedResult = await SocialService.getFeedPosts();
      final posts = feedResult['posts'] as List<Map<String, dynamic>>;
      final lastDoc = feedResult['lastDoc'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          _todayWorkouts = workouts;
          _todayProtein = protein;
          _upcomingEvents = events;
          _userName = profile[ProfileService.keyName] ?? '';
          _userPhotoUrl = profile[ProfileService.keyPhotoUrl];
          _baseTargetProtein = profile[ProfileService.keyTargetProtein] ?? 0.0;
          _unreadNotifs = unread;
          _feedPosts = posts;
          _lastFeedDoc = lastDoc;
          _hasMoreData = posts.isNotEmpty;
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: $e");
      if (mounted) setState(() => _isLoadingFeed = false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadScheduleOnly(DateTime date) async {
    setState(() {
      _selectedScheduleDate = date;
    });
    final events = await _db.getScheduleEventsByDate(date);
    if (mounted) {
      setState(() {
        _upcomingEvents = events;
      });
    }
  }

  Future<void> _navigateByWorkoutType(ScheduleEvent event) async {
    final profile = await ProfileService.getProfile();
    final weight = profile[ProfileService.keyWeight] ?? 70.0;
    if (!mounted) return;

    switch (event.workoutType) {
      case 'running':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RunningTrackerScreen(userWeight: weight)),
        ).then((_) => _loadData());
        break;
      case 'weightlifting':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WorkoutSetupScreen(userWeight: weight)),
        ).then((_) => _loadData());
        break;
      default:
        // Fallback: go to Workout tab
        widget.onGoToWorkout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.surface,
                surfaceTintColor: Colors.transparent, // Mencegah perubahan warna saat di-scroll
                scrolledUnderElevation: 0, // Memastikan tidak ada bayangan/warna tambahan
                elevation: 0,
                floating: true,
                snap: false,
                automaticallyImplyLeading: false,
                titleSpacing: context.spaceXL,
                title: _buildHeader(),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.spaceLG),
                
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: AppTheme.accent))
                else ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
                    child: Column(
                      children: [
                        _buildProteinCard(),
                        SizedBox(height: context.space2XL),
                        _buildStatGrid(),
                        SizedBox(height: context.space2XL),
                      ],
                    ),
                  ),
                    
                  _buildSocialFeed(),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty) {
      if (_userPhotoUrl!.startsWith('data:image')) {
        return ClipOval(child: Image.memory(base64Decode(_userPhotoUrl!.split(',')[1]), fit: BoxFit.cover, width: 40, height: 40));
      }
      return ClipOval(child: Image.network(_userPhotoUrl!, fit: BoxFit.cover, width: 40, height: 40));
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: AppTheme.surfaceVariant, shape: BoxShape.circle),
      child: Icon(Icons.person, color: AppTheme.textMuted, size: 24),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          AppTheme.isDarkMode 
              ? 'assets/icons/logoGelapTanpaIcon.png' 
              : 'assets/icons/logoTerangTanpaIcon.png',
          height: 14, // Diperkecil lagi sesuai permintaan
          fit: BoxFit.contain,
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.search, color: AppTheme.textPrimary),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none, color: AppTheme.textPrimary),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                    _loadData();
                  },
                ),
                if (_unreadNotifs > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadData());
              },
              child: _buildAvatar(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProteinCard() {
    final gap = _totalProteinNeeded - _totalProteinToday;
    final isSufficient = gap <= 0;
    final progress = _totalProteinNeeded > 0
        ? (_totalProteinToday / _totalProteinNeeded).clamp(0.0, 1.0)
        : 0.0;
        
    return Container(
      padding: EdgeInsets.all(context.spaceXL),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAPAIAN PROTEIN', style: TextStyle(fontSize: context.fontSM * 0.9, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1.5)),
                    SizedBox(height: context.spaceXS),
                    Text(
                      isSufficient ? 'Target tercapai!' : 'Di bawah target harian',
                      style: TextStyle(fontSize: context.fontBase, fontWeight: FontWeight.bold, color: isSufficient ? AppTheme.accent : AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spaceSM),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(fontSize: context.font2XL * 1.15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TERKUMPUL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  Text('${_totalProteinToday.toStringAsFixed(1)}g', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TARGET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  Text('${_totalProteinNeeded.toStringAsFixed(1)}g', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ],
              ),
            ],
          ),

        ],
      ),
    );
  }



  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3, // Memberikan ruang vertikal lebih agar tidak overflow
      children: [
        _buildStatBox(title: 'Nutrisi', value: '${_totalProteinToday.toStringAsFixed(0)}g', color: AppTheme.accent),
        _buildStatBox(title: 'Energi', value: '$_totalCaloriesToday', subValue: 'Kkal', color: AppTheme.accent),
        _buildStatBox(title: 'Durasi', value: '$_totalWorkoutMinutes', subValue: 'Menit', color: AppTheme.accent),
        _buildStatBox(title: 'Sesi', value: '${_todayWorkouts.length} Sesi', color: AppTheme.accent),
      ],
    );
  }

  Widget _buildStatBox({required String title, required String value, String? subValue, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Text(subValue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
              ],
            ],
          ),
        ],
      ),
    );
  }




  Widget _buildSocialFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
          child: Row(
            children: [
              Text('Aktivitas ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: -0.5)),
              Text('Teman', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: -0.5)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_isLoadingFeed)
          Center(child: CircularProgressIndicator(color: AppTheme.accent))
        else if (_feedPosts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Icon(Icons.group_outlined, size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ikuti lebih banyak teman untuk melihat aktivitas mereka di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          )
        else
          ..._feedPosts.asMap().entries.map((entry) {
            final post = entry.value;
            return FeedPostCard(
              key: ValueKey(post['postId']),
              post: post,
              onDataChanged: () => _loadData(silent: true),
            );
          }),

        // ── Load More indicator ──────────────────────────────────────────
        if (_isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
          )
        else if (!_hasMoreData && _feedPosts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '— Sudah mencapai akhir —',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ),
      ],
    );
  }
}
