import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/workout.dart';
import '../models/protein_entry.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/whistleblower_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/prefetch_manager.dart';
import '../widgets/shimmer_stat_box.dart';
import '../widgets/shimmer_feed_card.dart';
import '../widgets/shimmer_stat_box.dart';
import '../widgets/shimmer_feed_card.dart';
import 'dart:async';
import 'search_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'workout_detail_screen.dart';
import 'running_tracker_screen.dart';
import 'workout_setup_screen.dart';
import '../widgets/feed_post_card.dart';
import '../utils/responsive.dart';
import 'package:lottie/lottie.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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

  // ── Metrics Dashboard State ──────────────────────────────────────────────
  int _todayCaloriesConsumed = 0;
  int _todayCaloriesBurned = 0;
  int _todayWorkoutDuration = 0;
  double _todayWorkoutDistance = 0.0;
  int _currentWorkoutStreak = 0;

  // ── Pagination state ───────────────────────────────────────────────────
  DocumentSnapshot? _lastFeedDoc;
  bool _isLoadingMore = false; // Debounce: prevent multiple simultaneous loads
  bool _hasMoreData = true; // Flag: false when last page is empty
  late ScrollController _scrollController;

  Timer? _whistleTimer;

  double get _totalProteinToday =>
      _todayProtein.fold(0, (sum, e) => sum + e.proteinGrams);
  double get _totalProteinNeeded => _baseTargetProtein;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _whistleTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkWhistleblower();
    });

    final pm = PrefetchManager.instance;
    if (pm.hasData) {
      _applyPrefetchedData(pm);
      _backgroundSync(); // Fire and forget
    } else {
      _initialSyncAndLoad();
    }
  }

  void _applyPrefetchedData(PrefetchManager pm) {
    _isLoading = false;
    _isLoadingFeed = false;

    _todayWorkouts = pm.todayWorkouts ?? [];
    _todayProtein = pm.todayProtein ?? [];
    _upcomingEvents = pm.upcomingEvents ?? [];

    if (pm.userProfile != null) {
      _userName = pm.userProfile!['name'] ?? '';
      _userPhotoUrl = pm.userProfile!['photoUrl'];
      _baseTargetProtein =
          (pm.userProfile!['targetProtein'] as num?)?.toDouble() ?? 0.0;
    }

    _unreadNotifs = pm.unreadNotificationCount ?? 0;
    _todayCaloriesConsumed = pm.todayCaloriesConsumed ?? 0;
    _todayCaloriesBurned =
        (pm.todayWorkoutMetrics?['caloriesBurned'] as num?)?.toInt() ?? 0;
    _todayWorkoutDuration =
        (pm.todayWorkoutMetrics?['duration'] as num?)?.toInt() ?? 0;
    _todayWorkoutDistance =
        (pm.todayWorkoutMetrics?['distance'] as num?)?.toDouble() ?? 0.0;
    _currentWorkoutStreak = pm.currentWorkoutStreak?['current'] ?? 0;

    if (pm.limitedActivityFeed != null) {
      _feedPosts = pm.limitedActivityFeed!;
      _hasMoreData = _feedPosts.isNotEmpty;
    }
  }

  Future<void> _backgroundSync() async {
    try {
      if (AuthService.isLoggedIn) {
        bool isEmpty = await CloudSyncService.isLocalDataEmpty();
        if (isEmpty) {
          await CloudSyncService.restoreAllFromCloud()
              .timeout(const Duration(seconds: 5));
        } else {
          await CloudSyncService.syncWorkoutsToCloud();
          await CloudSyncService.syncNutritionToCloud();
        }
      }
    } catch (_) {}

    if (mounted) {
      _loadData(silent: true);
    }
  }

  Future<void> _initialSyncAndLoad() async {
    setState(() => _isLoading = true);
    try {
      if (AuthService.isLoggedIn) {
        bool isEmpty = await CloudSyncService.isLocalDataEmpty();
        if (isEmpty) {
          await CloudSyncService.restoreAllFromCloud()
              .timeout(const Duration(seconds: 5));
        } else {
          await CloudSyncService.syncWorkoutsToCloud();
          await CloudSyncService.syncNutritionToCloud();
        }
      }
    } catch (_) {
      // Abaikan error jaringan
    }
    await _loadData();
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
        _scrollController.position.maxScrollExtent * 0.7) {
      _loadMoreFeed();
    }
  }

  Future<void> _loadMoreFeed() async {
    // Debounce: skip if already loading or no more data
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await SocialService.getFeedPosts(
        startAfter: _lastFeedDoc,
        limit: 10,
      );
      final newPosts = result['posts'] as List<Map<String, dynamic>>;
      final newLastDoc = result['lastDoc'] as DocumentSnapshot?;

      if (mounted) {
        setState(() {
          // Merge-Union logic: Only add posts that don't already exist in _feedPosts
          final existingIds = _feedPosts.map((p) => p['id'] ?? '').toSet();
          for (var post in newPosts) {
            if (!existingIds.contains(post['id'] ?? '')) {
              _feedPosts.add(post);
              existingIds.add(post['id'] ?? '');
            }
          }
          _lastFeedDoc = newLastDoc;
          _hasMoreData = newPosts.length >= 10;
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
                Text('Waktunya Action!',
                    style: TextStyle(color: AppTheme.textPrimary)),
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
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
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
      if (AuthService.isLoggedIn) {
        bool isEmpty = await CloudSyncService.isLocalDataEmpty();
        if (isEmpty) {
          await CloudSyncService.restoreAllFromCloud()
              .timeout(const Duration(seconds: 5));
        } else {
          await CloudSyncService.syncWorkoutsToCloud();
          await CloudSyncService.syncNutritionToCloud();
        }
      }
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
      final workoutStreak = await _db.getCalculateWorkoutStreak();

      // Load new metrics
      final consumedCals = await _db.getTodayCaloriesConsumed();
      final workoutMetrics = await _db.getTodayWorkoutMetrics();

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

          _todayCaloriesConsumed = consumedCals;
          _todayCaloriesBurned =
              (workoutMetrics['caloriesBurned'] as num).toInt();
          _todayWorkoutDuration = (workoutMetrics['duration'] as num).toInt();
          _todayWorkoutDistance =
              (workoutMetrics['distance'] as num).toDouble();
          _currentWorkoutStreak = workoutStreak['current'] ?? 0;

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
          MaterialPageRoute(
              builder: (_) => RunningTrackerScreen(userWeight: weight)),
        ).then((_) => _loadData());
        break;
      case 'weightlifting':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => WorkoutSetupScreen(userWeight: weight)),
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
                surfaceTintColor: Colors
                    .transparent, // Mencegah perubahan warna saat di-scroll
                scrolledUnderElevation:
                    0, // Memastikan tidak ada bayangan/warna tambahan
                elevation: 0,
                floating: true,
                snap: false,
                automaticallyImplyLeading: false,
                titleSpacing: context.spaceXL,
                title: _buildHeader(),
              ),
              if (_isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
                    child: Column(
                      children: [
                        SizedBox(height: context.spaceLG),
                        const ShimmerProteinCard(),
                        SizedBox(height: context.space2XL),
                        Row(
                          children: const [
                            Expanded(child: ShimmerStatBox()),
                            SizedBox(width: 16),
                            Expanded(child: ShimmerStatBox()),
                          ],
                        ),
                        SizedBox(height: context.space2XL),
                        Row(
                          children: const [
                            Expanded(child: ShimmerStatBox()),
                            SizedBox(width: 16),
                            Expanded(child: ShimmerStatBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.spaceLG),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: context.spaceXL),
                        child: Column(
                          children: [
                            _buildProteinCard(),
                            SizedBox(height: context.space2XL),
                            _buildStatGrid(),
                            SizedBox(height: context.space2XL),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ..._buildSocialFeedSlivers(),
              ],
            ],
          ),
        ),
      ),
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
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none,
                      color: AppTheme.textPrimary),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationScreen()));
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
                    Text('CAPAIAN PROTEIN',
                        style: TextStyle(
                            fontSize: context.fontSM * 0.9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.5)),
                    SizedBox(height: context.spaceXS),
                    Text(
                      isSufficient
                          ? 'Target tercapai!'
                          : 'Di bawah target harian',
                      style: TextStyle(
                          fontSize: context.fontBase,
                          fontWeight: FontWeight.bold,
                          color: isSufficient
                              ? AppTheme.accent
                              : AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spaceSM),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                    fontSize: context.font2XL * 1.15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary),
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
                  Text('TERKUMPUL',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                  Text('${_totalProteinToday.toStringAsFixed(1)}g',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TARGET',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                  Text('${_totalProteinNeeded.toStringAsFixed(1)}g',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
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
      childAspectRatio:
          1.3, // Memberikan ruang vertikal lebih agar tidak overflow
      children: [
        _buildStatBox(
            title: 'ASUPAN',
            value: '$_todayCaloriesConsumed',
            subValue: 'Kkal',
            color: AppTheme.accent,
            onTap: widget.onGoToProtein),
        _buildStatBox(
            title: 'ENERGI',
            value: '$_todayCaloriesBurned',
            subValue: 'Kkal',
            color: AppTheme.accent),
        _buildStatBox(
            title: 'DURASI',
            value: '$_todayWorkoutDuration',
            subValue: 'Menit',
            color: AppTheme.accent),
        _buildStatBox(
            title: 'JARAK',
            value: _todayWorkoutDistance.toStringAsFixed(1),
            subValue: 'Km',
            color: AppTheme.accent),
      ],
    );
  }

  Widget _buildStatBox(
      {required String title,
      required String value,
      String? subValue,
      required Color color,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(value,
                      key: ValueKey<String>(value),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary)),
                ),
                if (subValue != null) ...[
                  const SizedBox(width: 4),
                  Text(subValue,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSocialFeedSlivers() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
          child: Row(
            children: [
              Text('Aktivitas ',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5)),
              Text('Teman',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(child: const SizedBox(height: 24)),

      if (_isLoadingFeed)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
            child: Column(
              children: List.generate(3, (index) => const ShimmerFeedCard()),
            ),
          ),
        )
      else if (_feedPosts.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
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
                  Icon(Icons.group_outlined,
                      size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary),
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
          ),
        )
      else
        SliverList.builder(
          itemCount: _feedPosts.length,
          itemBuilder: (context, index) {
            final post = _feedPosts[index];
            return FeedPostCard(
              key: ValueKey(post['postId']),
              post: post,
              onDataChanged: () => _loadData(silent: true),
            );
          },
        ),

      // ── Load More indicator ──────────────────────────────────────────
      if (_isLoadingMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2)),
          ),
        )
      else if (!_hasMoreData && _feedPosts.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '— Sudah mencapai akhir —',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
    ];
  }
}
