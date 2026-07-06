import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/protein_entry.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/schedule_event.dart';
import '../models/body_measurement.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'Kora.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        duration REAL NOT NULL,
        distance REAL,
        sets INTEGER,
        reps INTEGER,
        weight REAL,
        caloriesBurned INTEGER NOT NULL,
        proteinNeeded REAL NOT NULL,
        notes TEXT,
        date TEXT NOT NULL,
        movingTime REAL,
        elevationGain REAL,
        maxElevation REAL,
        photoPath TEXT,
        splitsStr TEXT,
        polyline TEXT,
        title TEXT,
        photosJson TEXT
      )
    ''');
// ... (rest of onCreate same as before)
    

    await db.execute('''
      CREATE TABLE schedule_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        workoutType TEXT,
        durationMinutes INTEGER,
        notes TEXT,
        isCompleted INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE body_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        bodyFatPercentage REAL,
        chest REAL,
        waist REAL,
        hips REAL,
        biceps REAL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profiles (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        photoUrl TEXT,
        age INTEGER DEFAULT 0,
        gender TEXT DEFAULT 'Laki-laki',
        height REAL DEFAULT 0.0,
        weight REAL DEFAULT 0.0,
        goal TEXT DEFAULT 'Bulking',
        targetProtein REAL DEFAULT 0.0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_name TEXT NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE temp_tracking_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');

    // ── Database Indexes — optimasi query tanggal & GROUP BY ──────────
    // Index pada kolom yang sering dipakai di WHERE / BETWEEN / ORDER BY / GROUP BY.
    // Mengubah Full Table Scan → Index Scan (O(log n) vs O(n)).
    await db.execute('CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts (date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_protein_entries_date ON protein_entries (date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_protein_entries_food_name ON protein_entries (foodName)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedule_events_date_time ON schedule_events (dateTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_body_measurements_date ON body_measurements (date)');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('workouts');
    await db.delete('workout_photos');
    await db.delete('protein_entries');
    await db.delete('schedule_events');
    await db.delete('body_measurements');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN carbsGrams REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN fatGrams REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN fiberGrams REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN sugarGrams REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN saltGrams REAL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN waterMl INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS body_measurements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            weight REAL NOT NULL,
            height REAL NOT NULL,
            bodyFatPercentage REAL,
            chest REAL,
            waist REAL,
            hips REAL,
            biceps REAL,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE protein_entries ADD COLUMN emojiStr TEXT'); } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE workouts ADD COLUMN movingTime REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE workouts ADD COLUMN elevationGain REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE workouts ADD COLUMN maxElevation REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE workouts ADD COLUMN photoPath TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE workouts ADD COLUMN splitsStr TEXT'); } catch (_) {}
    }
    if (oldVersion < 7) {
      try { await db.execute('ALTER TABLE workouts ADD COLUMN title TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE workouts ADD COLUMN photosJson TEXT'); } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            uid TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT,
            photoUrl TEXT,
            age INTEGER DEFAULT 0,
            gender TEXT DEFAULT 'Laki-laki',
            height REAL DEFAULT 0.0,
            weight REAL DEFAULT 0.0,
            goal TEXT DEFAULT 'Bulking',
            targetProtein REAL DEFAULT 0.0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS workout_sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workout_id INTEGER NOT NULL,
            exercise_name TEXT NOT NULL,
            weight REAL NOT NULL,
            reps INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS protein_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            foodName TEXT NOT NULL,
            proteinGrams REAL NOT NULL,
            calories REAL DEFAULT 0.0,
            carbsGrams REAL DEFAULT 0.0,
            fatGrams REAL DEFAULT 0.0,
            fiberGrams REAL DEFAULT 0.0,
            sugarGrams REAL DEFAULT 0.0,
            saltGrams REAL DEFAULT 0.0,
            waterMl INTEGER DEFAULT 0,
            emojiStr TEXT
          );
          CREATE TABLE IF NOT EXISTS temp_tracking_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try { await db.execute("ALTER TABLE schedule_events ADD COLUMN status TEXT DEFAULT 'pending'"); } catch (_) {}
      try { await db.execute("UPDATE schedule_events SET status = 'done' WHERE isCompleted = 1"); } catch (_) {}
    }
    // ── v11: Normalisasi foto ke tabel terpisah (lazy loading) ──────────────
    if (oldVersion < 11) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS workout_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workout_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
          )
        ''');

        // Migrasi data: pindahkan photoPath & photosJson ke tabel baru
        final workouts = await db.query('workouts');
        for (final w in workouts) {
          final workoutId = w['id'] as int;
          final now = DateTime.now().toIso8601String();
          int order = 0;

          // Migrasi photosJson (JSON array of file paths)
          final photosJson = w['photosJson'] as String?;
          if (photosJson != null && photosJson.isNotEmpty) {
            try {
              final List<dynamic> paths = _jsonDecodeSafe(photosJson);
              for (final p in paths) {
                if (p is String && p.isNotEmpty) {
                  await db.insert('workout_photos', {
                    'workout_id': workoutId,
                    'file_path': p,
                    'sort_order': order++,
                    'created_at': now,
                  });
                }
              }
            } catch (_) {}
          }

          // Migrasi photoPath (single path, legacy)
          final photoPath = w['photoPath'] as String?;
          if (photoPath != null && photoPath.isNotEmpty) {
            // Cek apakah sudah dipindahkan dari photosJson
            final existing = await db.query(
              'workout_photos',
              where: 'workout_id = ? AND file_path = ?',
              whereArgs: [workoutId, photoPath],
            );
            if (existing.isEmpty) {
              await db.insert('workout_photos', {
                'workout_id': workoutId,
                'file_path': photoPath,
                'sort_order': order,
                'created_at': now,
              });
            }
          }
        }
      } catch (_) {}
    }

    // ── v12: Database Indexes — optimasi Full Table Scan ─────────────────
    // Menambahkan B-tree index pada kolom yang sering di-query dengan
    // BETWEEN / LIKE / ORDER BY / GROUP BY. Aman: IF NOT EXISTS + try-catch
    // per baris agar tidak merusak skema jika index sudah ada.
    if (oldVersion < 12) {
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts (date)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_protein_entries_date ON protein_entries (date)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_protein_entries_food_name ON protein_entries (foodName)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_schedule_events_date_time ON schedule_events (dateTime)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_body_measurements_date ON body_measurements (date)'); } catch (_) {}
    }
  }

  /// Helper: safe JSON decode untuk migrasi
  static List<dynamic> _jsonDecodeSafe(String str) {
    try {
      final result = jsonDecode(str);
      return result is List ? result : [];
    } catch (_) {
      return [];
    }
  }

  // ---- WORKOUT METHODS ----
  Future<Map<String, double>> getWeeklyWorkoutStats(String type) async {
    final db = await database;
    final now = DateTime.now();
    // Get last 7 days including today
    Map<String, double> stats = {};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
      
      final result = await db.rawQuery(
        'SELECT SUM(distance) as total FROM workouts WHERE type = ? AND date LIKE ?',
        [type, '$dateStr%']
      );
      
      double total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      stats[dateStr] = total;
    }
    return stats;
  }
  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return await db.insert('workouts', workout.toMap());
  }

  Future<List<Workout>> getWorkoutsByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'workouts',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  /// Fetch workouts within a date range, optionally filtered by type.
  Future<List<Workout>> getWorkoutsByDateRange({
    required DateTime start,
    required DateTime end,
    String? type,
  }) async {
    final db = await database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    if (type != null && type.isNotEmpty) {
      final maps = await db.query(
        'workouts',
        where: 'date BETWEEN ? AND ? AND type = ?',
        whereArgs: [startStr, endStr, type],
        orderBy: 'date ASC',
      );
      return maps.map((m) => Workout.fromMap(m)).toList();
    }
    final maps = await db.query(
      'workouts',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC',
    );
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final maps = await db.query('workouts', orderBy: 'date DESC');
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  Future<List<Workout>> getRecentWorkouts({int limit = 7}) async {
    final db = await database;
    final maps = await db.query('workouts', orderBy: 'date DESC', limit: limit);
    return maps.map((m) => Workout.fromMap(m)).toList();
  }

  /// Menghitung total hari berturut-turut (Streak) dari tabel workouts
  /// menggunakan Aturan 48 Jam (Aman jika hari ini belum latihan tapi kemarin sudah)
  /// Bug DST (Daylight Saving Time) dicegah dengan menggunakan list hari unik dan DateTime(YYYY-MM-DD).
  Future<Map<String, int>> getCalculateWorkoutStreak() async {
    final db = await database;
    // Mengambil tanggal unik berformat 'YYYY-MM-DD' secara descending dari SQLite
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT substr(date, 1, 10) as dateStr 
      FROM workouts 
      ORDER BY dateStr DESC
    ''');
    
    if (maps.isEmpty) return {'current': 0, 'best': 0};
    
    List<String> dates = maps.map((m) => m['dateStr'] as String).toList();
    
    // Calculate Best Streak
    int bestStreak = 0;
    int tempStreak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      DateTime d1 = DateTime.parse(dates[i]);
      DateTime d2 = DateTime.parse(dates[i+1]);
      int diff = DateTime(d1.year, d1.month, d1.day).difference(DateTime(d2.year, d2.month, d2.day)).inDays;
      if (diff == 1) {
        tempStreak++;
      } else {
        if (tempStreak > bestStreak) bestStreak = tempStreak;
        tempStreak = 1;
      }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;
    if (dates.length == 1) bestStreak = 1;
    
    // Calculate Current Streak
    int currentStreak = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    
    String todayStr = today.toIso8601String().split('T')[0];
    String yesterdayStr = yesterday.toIso8601String().split('T')[0];
    
    bool hasToday = dates.contains(todayStr);
    bool hasYesterday = dates.contains(yesterdayStr);
    
    // Aturan Patah: Jika tidak ada log hari ini DAN kemarin, currentStreak = 0
    if (!hasToday && !hasYesterday) {
      currentStreak = 0;
    } else {
      // Tentukan titik awal hitung mundur
      DateTime checkDate = hasToday ? today : yesterday;
      
      // Hitung mundur hari secara aman dari DST
      for (int i = 0; i < dates.length; i++) {
        DateTime expectedDate = DateTime(checkDate.year, checkDate.month, checkDate.day - i);
        String expectedDateStr = expectedDate.toIso8601String().split('T')[0];
        
        if (dates.contains(expectedDateStr)) {
          currentStreak++;
        } else {
          break;
        }
      }
    }
    
    return {'current': currentStreak, 'best': bestStreak};
  }

  Future<int> deleteWorkout(int id) async {
    final db = await database;
    // Hapus foto terkait dulu (FK cascade tidak aktif by default di SQLite)
    await db.delete('workout_photos', where: 'workout_id = ?', whereArgs: [id]);
    return await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await database;
    return await db.update(
      'workouts',
      workout.toMap(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  // ---- WORKOUT PHOTOS (LAZY LOADING) ----

  /// Ambil semua foto workout berdasarkan workout_id.
  /// Hanya dipanggil saat UI benar-benar butuh menampilkan foto (lazy).
  Future<List<String>> getWorkoutPhotos(int workoutId) async {
    final db = await database;
    final maps = await db.query(
      'workout_photos',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => m['file_path'] as String).toList();
  }

  /// Cek apakah workout memiliki foto (ringan — tanpa load data foto).
  /// Berguna untuk thumbnail indicator di list view.
  Future<bool> workoutHasPhotos(int workoutId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM workout_photos WHERE workout_id = ?',
      [workoutId],
    );
    return (result.first['cnt'] as int) > 0;
  }

  /// Batch check: dari daftar workoutId, kembalikan Set ID yang punya foto.
  /// Lebih efisien daripada N kali workoutHasPhotos() untuk list view.
  Future<Set<int>> getWorkoutIdsWithPhotos(List<int> workoutIds) async {
    if (workoutIds.isEmpty) return {};
    final db = await database;
    final placeholders = workoutIds.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT workout_id FROM workout_photos WHERE workout_id IN ($placeholders)',
      workoutIds,
    );
    return result.map((r) => r['workout_id'] as int).toSet();
  }

  /// Ambil file_path foto pertama (sort_order terendah) untuk thumbnail.
  Future<String?> getFirstWorkoutPhoto(int workoutId) async {
    final db = await database;
    final result = await db.query(
      'workout_photos',
      columns: ['file_path'],
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['file_path'] as String?;
  }

  /// Tambah foto ke workout tertentu.
  Future<int> addWorkoutPhoto(int workoutId, String filePath, {int? sortOrder}) async {
    final db = await database;
    // Auto-assign sort_order jika tidak diberikan
    final order = sortOrder ?? await _getNextPhotoOrder(workoutId);
    return await db.insert('workout_photos', {
      'workout_id': workoutId,
      'file_path': filePath,
      'sort_order': order,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Hapus satu foto berdasarkan ID.
  Future<int> deleteWorkoutPhoto(int photoId) async {
    final db = await database;
    return await db.delete('workout_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  /// Hapus semua foto milik workout tertentu.
  Future<int> deleteAllWorkoutPhotos(int workoutId) async {
    final db = await database;
    return await db.delete(
      'workout_photos',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }

  /// Helper: dapatkan sort_order berikutnya untuk workout tertentu.
  Future<int> _getNextPhotoOrder(int workoutId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM workout_photos WHERE workout_id = ?',
      [workoutId],
    );
    return ((result.first['max_order'] as int?) ?? -1) + 1;
  }

  // ---- METRICS FOR DASHBOARD ----
  Future<int> getTodayCaloriesConsumed() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(calories) as total FROM protein_entries WHERE date BETWEEN ? AND ?',
      [start, end]
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, num>> getTodayWorkoutMetrics() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(caloriesBurned) as calories, SUM(duration) as duration, SUM(distance) as distance FROM workouts WHERE date BETWEEN ? AND ?',
      [start, end]
    );
    return {
      'caloriesBurned': (result.first['calories'] as num?)?.toInt() ?? 0,
      'duration': (result.first['duration'] as num?)?.toInt() ?? 0,
      'distance': (result.first['distance'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ---- PROTEIN METHODS ----



  // Predictive search for frequent foods
  Future<List<String>> getFrequentFoods({String? mealType, int limit = 10}) async {
    final db = await database;
    String whereClause = 'waterMl = 0'; // only solid foods
    List<dynamic> whereArgs = [];
    
    if (mealType != null) {
      whereClause += ' AND mealType = ?';
      whereArgs.add(mealType);
    }
    
    final maps = await db.query(
      'protein_entries',
      columns: ['foodName', 'COUNT(*) as freq'],
      where: whereClause,
      whereArgs: whereArgs,
      groupBy: 'foodName',
      orderBy: 'freq DESC',
      limit: limit,
    );
    
    return maps.map((m) => m['foodName'] as String).toList();
  }


  // ---- SCHEDULE METHODS ----
  Future<int> insertScheduleEvent(ScheduleEvent event) async {
    final db = await database;
    return await db.insert('schedule_events', event.toMap());
  }

  Future<List<ScheduleEvent>> getScheduleEventsByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'schedule_events',
      where: 'dateTime BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'dateTime ASC',
    );
    return maps.map((m) => ScheduleEvent.fromMap(m)).toList();
  }

  Future<List<ScheduleEvent>> getUpcomingEvents() async {
    final db = await database;
    final now = DateTime.now();
    // Fetch incomplete events from the last 3 days up to future
    final limitDate = now.subtract(const Duration(days: 3)).toIso8601String();
    final maps = await db.query(
      'schedule_events',
      where: 'dateTime >= ? AND isCompleted = 0',
      whereArgs: [limitDate],
      orderBy: 'dateTime ASC',
      limit: 10,
    );
    return maps.map((m) => ScheduleEvent.fromMap(m)).toList();
  }

  Future<List<ScheduleEvent>> getAllScheduleEvents() async {
    final db = await database;
    final maps = await db.query(
      'schedule_events',
      orderBy: 'dateTime ASC',
    );
    return maps.map((m) => ScheduleEvent.fromMap(m)).toList();
  }

  Future<void> checkLateSchedules() async {
    final db = await database;
    // Anggap gagal jika lewat 2 jam
    final limitTime = DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
    
    await db.update(
      'schedule_events',
      {'status': 'failed'},
      where: 'status = ? AND dateTime < ?',
      whereArgs: ['pending', limitTime],
    );
  }

  Future<int> updateScheduleEventCompletion(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'schedule_events',
      {
        'isCompleted': isCompleted ? 1 : 0,
        'status': isCompleted ? 'done' : 'pending'
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateScheduleEvent(ScheduleEvent event) async {
    final db = await database;
    return await db.update(
      'schedule_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteScheduleEvent(int id) async {
    final db = await database;
    return await db.delete('schedule_events', where: 'id = ?', whereArgs: [id]);
  }

  // ---- BODY MEASUREMENTS METHODS ----
  Future<int> insertBodyMeasurement(BodyMeasurement measurement) async {
    final db = await database;
    return await db.insert('body_measurements', measurement.toMap());
  }

  Future<List<BodyMeasurement>> getAllBodyMeasurements() async {
    final db = await database;
    final maps = await db.query('body_measurements', orderBy: 'date DESC');
    return maps.map((m) => BodyMeasurement.fromMap(m)).toList();
  }

  Future<BodyMeasurement?> getLatestBodyMeasurement() async {
    final db = await database;
    final maps = await db.query(
      'body_measurements', 
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BodyMeasurement.fromMap(maps.first);
  }

  Future<int> deleteBodyMeasurement(int id) async {
    final db = await database;
    return await db.delete('body_measurements', where: 'id = ?', whereArgs: [id]);
  }

  // ---- USER PROFILE METHODS ----
  Future<void> upsertUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    final existing = await db.query(
      'user_profiles',
      where: 'uid = ?',
      whereArgs: [profile['uid']],
    );
    if (existing.isEmpty) {
      await db.insert('user_profiles', profile);
    } else {
      await db.update(
        'user_profiles',
        profile,
        where: 'uid = ?',
        whereArgs: [profile['uid']],
      );
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> deleteUserProfile(String uid) async {
    final db = await database;
    await db.delete('user_profiles', where: 'uid = ?', whereArgs: [uid]);
  }

  Future<void> insertNutritionLog({
    required String foodName,
    required double protein,
    required double calories,
    required double carbs,
    required double fat,
    required double fiber,
    required double sugar,
    required double salt,
  }) async {
    final db = await database;
    await db.insert(
      'protein_entries',
      {
        'date': DateTime.now().toIso8601String(),
        'foodName': foodName,
        'proteinGrams': protein,
        'calories': calories,
        'carbsGrams': carbs,
        'fatGrams': fat,
        'fiberGrams': fiber,
        'sugarGrams': sugar,
        'saltGrams': salt,
      },
    );
  }

  Future<List<ProteinEntry>> getProteinEntriesByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'protein_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((e) => ProteinEntry.fromMap(e)).toList();
  }

  Future<List<ProteinEntry>> getProteinEntriesByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'protein_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((e) => ProteinEntry.fromMap(e)).toList();
  }

  Future<void> deleteProteinEntry(int id) async {
    final db = await database;
    await db.delete(
      'protein_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertProteinEntry(ProteinEntry entry) async {
    final db = await database;
    return await db.insert('protein_entries', entry.toMap());
  }
}
