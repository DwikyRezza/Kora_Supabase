class PrefetchManager {
  // Singleton pattern
  static final PrefetchManager _instance = PrefetchManager._internal();
  factory PrefetchManager() => _instance;
  static PrefetchManager get instance => _instance;
  PrefetchManager._internal();

  // Data properties
  Map<String, dynamic>? userProfile;
  int? todayCaloriesConsumed;
  Map<String, num>? todayWorkoutMetrics;
  Map<String, int>? currentWorkoutStreak;
  int? unreadNotificationCount;
  List<Map<String, dynamic>>? limitedActivityFeed;
  
  // Other data needed by HomeScreen to prevent null errors or additional loads
  dynamic todayWorkouts;
  dynamic todayProtein;
  dynamic upcomingEvents;

  /// Cek apakah data utama sudah terisi (tidak null)
  bool get hasData => userProfile != null && todayWorkoutMetrics != null;

  /// Mengosongkan cache saat user logout
  void clearCache() {
    userProfile = null;
    todayCaloriesConsumed = null;
    todayWorkoutMetrics = null;
    currentWorkoutStreak = null;
    unreadNotificationCount = null;
    limitedActivityFeed = null;
    todayWorkouts = null;
    todayProtein = null;
    upcomingEvents = null;
  }
}
