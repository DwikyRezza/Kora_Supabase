import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../utils/tab_visibility.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../../models/workout.dart';
import '../../../../models/schedule_event.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/whistleblower_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/social_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/prefetch_manager.dart';
import '../../../../widgets/shimmer_stat_box.dart';
import '../../../../widgets/shimmer_feed_card.dart';
import '../../../../widgets/home_screen/home_screen_components.dart';
import 'dart:async';
import '../../../../screens/search_screen.dart';
import '../../../../screens/notification_screen.dart';
import '../../../../features/running/presentation/screens/running_screen.dart';
import '../../../../screens/workout_setup_screen.dart';
import '../../../../widgets/feed_post_card.dart';
import '../../../../utils/responsive.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/home_bloc.dart';
import '../../bloc/home_event.dart';
import '../../bloc/home_state.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  
  HomeState get state => context.watch<HomeBloc>().state;

  bool get _isLoading => state.status == HomeStatus.loading || state.status == HomeStatus.initial;
  String get _userName => state.userName;
  String? get _userPhotoUrl => state.userPhotoUrl;
  double get _baseTargetProtein => state.baseTargetProtein;
  double get _targetCalories => state.targetCalories;
  int get _unreadNotifs => state.unreadNotifs;
  List<Workout> get _todayWorkouts => state.todayWorkouts;
  List<ScheduleEvent> get _upcomingEvents => state.upcomingEvents;
  int get _todayCaloriesConsumed => state.todayCaloriesConsumed;
  int get _todayCaloriesBurned => state.todayCaloriesBurned;
  int get _todayWorkoutDuration => state.todayWorkoutDuration;
  double get _todayWorkoutDistance => state.todayWorkoutDistance;
  int get _currentWorkoutStreak => state.currentWorkoutStreak;
  List<Map<String, dynamic>> get _feedPosts => state.feedPosts;
  bool get _isLoadingMore => state.isLoadingMore;
  bool get _hasMoreData => state.hasMoreData;
  int get _dashboardTab => state.dashboardTab;
  double get _totalProteinToday => state.totalProteinToday;
  double get _totalProteinNeeded => state.totalProteinNeeded;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    context.read<HomeBloc>().add(const HomeLoadData());
    
    TabVisibility.instance.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (TabVisibility.instance.activeTab == 0 && mounted) {
      context.read<HomeBloc>().add(const HomeLoadData());
    }
  }

  @override
  void dispose() {
    TabVisibility.instance.removeListener(_onTabChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.7) {
      context.read<HomeBloc>().add(HomeLoadMoreFeed());
    }
  }

  Future<void> _refreshData() async {
    context.read<HomeBloc>().add(const HomeLoadData(isRefresh: true));
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
                        const Row(
                          children: [
                            Expanded(child: ShimmerStatBox()),
                            SizedBox(width: 16),
                            Expanded(child: ShimmerStatBox()),
                          ],
                        ),
                        SizedBox(height: context.space2XL),
                        const Row(
                          children: [
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
                            _buildDashboardCard(),
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
                    context.read<HomeBloc>().add(const HomeLoadData(isRefresh: true));
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



  Widget _buildNutritionTab() {
    final proteinProgress = _totalProteinNeeded > 0
        ? (_totalProteinToday / _totalProteinNeeded).clamp(0.0, 1.0)
        : 0.0;
        
    final caloriesProgress = _targetCalories > 0
        ? (_todayCaloriesConsumed / _targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      key: const ValueKey('Nutrition'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kalori
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Kalori', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('$_todayCaloriesConsumed / ${_targetCalories.toInt()} Kkal', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: caloriesProgress,
            child: Container(
              decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Protein
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Protein', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${_totalProteinToday.toStringAsFixed(1)} / ${_totalProteinNeeded.toStringAsFixed(1)} g', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: proteinProgress,
            child: Container(
              decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return Container(
      key: const ValueKey('Activity'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildActivityItem(Icons.local_fire_department_outlined, 'Energi', '$_todayCaloriesBurned', 'Kkal')),
          Container(width: 1, height: 40, color: AppTheme.border),
          Expanded(child: _buildActivityItem(Icons.timer_outlined, 'Durasi', '$_todayWorkoutDuration', 'Min')),
          Container(width: 1, height: 40, color: AppTheme.border),
          Expanded(child: _buildActivityItem(Icons.route_outlined, 'Jarak', _todayWorkoutDistance.toStringAsFixed(1), 'Km')),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String label, String value, String unit) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppTheme.accent, size: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(width: 2),
            Text(unit, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildDashboardCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _dashboardTab == 0 ? 'CAPAIAN NUTRISI' : 'AKTIVITAS HARI INI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PillToggle(
                dashboardTab: _dashboardTab,
                onTabChanged: (index) => context.read<HomeBloc>().add(HomeChangeTab(index)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100, // Fixed height to prevent layout shift during transition
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _dashboardTab == 0 ? _buildNutritionTab() : _buildActivityTab(),
            ),
          ),
        ],
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
      const SliverToBoxAdapter(child: SizedBox(height: 24)),

      if ((state.status == HomeStatus.loading))
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
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
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
              onDataChanged: () => context.read<HomeBloc>().add(const HomeLoadData(isRefresh: true)),
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

class StatBoxWidget extends StatefulWidget {
  final String title;
  final String value;
  final String subValue;
  final VoidCallback? onTap;

  const StatBoxWidget({
    super.key,
    required this.title,
    required this.value,
    required this.subValue,
    this.onTap,
  });

  @override
  State<StatBoxWidget> createState() => _StatBoxWidgetState();
}

class _StatBoxWidgetState extends State<StatBoxWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _animController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _animController.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode;
    
    // Background with very subtle gradient
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    // Layered Shadow
    final shadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ];

    final labelColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final valueColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: bgGradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                  width: 1,
                ),
                boxShadow: shadows,
              ),
              child: Stack(
                children: [
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              widget.value,
                              key: ValueKey<String>(widget.value),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: valueColor,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.subValue,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
