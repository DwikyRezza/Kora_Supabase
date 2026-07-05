import re

with open('lib/services/database_helper.dart', 'r', encoding='utf-8') as f:
    db_content = f.read()

# 1. Re-add CREATE TABLE protein_entries
create_table_str = '''          CREATE TABLE IF NOT EXISTS protein_entries (
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
          CREATE TABLE IF NOT EXISTS temp_tracking_points ('''

db_content = db_content.replace('          CREATE TABLE IF NOT EXISTS temp_tracking_points (', create_table_str)

# 2. Add insertNutritionLog method at the end of DatabaseHelper (before the last closing brace)
insert_log_str = '''
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
}
'''
db_content = re.sub(r'}\s*$', insert_log_str, db_content)

with open('lib/services/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(db_content)

# 3. Update ai_nutrition_screen.dart to call this method and tell HomeBloc to reload
with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    ai_content = f.read()

# In _saveAll:
old_save = '''    BackgroundTaskQueue.instance.enqueue<void>(
      task: () => Future.value(),
      onError: (e) {
        // Rollback the optimistic update
        pm.todayCaloriesConsumed = prevCalories;

        // Show retry SnackBar ?" but we are now in background, so we need a global key or messenger.
        // We show it via the app's root scaffold by broadcasting via the main navigator
        debugPrint('[Optimistic] Nutrition save failed, rolled back. Error: ');
      },
    ).then((_) {
      // On success: fire cloud sync (also non-blocking)
      CloudSyncService.syncNutritionToCloud().catchError((_) {});
    });'''

new_save = '''    BackgroundTaskQueue.instance.enqueue<void>(
      task: () async {
        for (final r in results) {
          await db.insertNutritionLog(
            foodName: r.name,
            protein: r.protein,
            calories: r.calories,
            carbs: r.carbs,
            fat: r.fat,
            fiber: r.fiber,
            sugar: r.sugar,
            salt: r.salt,
          );
        }
      },
      onError: (e) {
        pm.todayCaloriesConsumed = prevCalories;
        debugPrint('[Optimistic] Nutrition save failed, rolled back. Error: ');
      },
    ).then((_) {
      CloudSyncService.syncNutritionToCloud().catchError((_) {});
    });'''

ai_content = ai_content.replace(old_save, new_save)
# Fix the error string with unknown character from previous string replacer
ai_content = ai_content.replace('SnackBar ?" but we are now', 'SnackBar - but we are now')
ai_content = ai_content.replace('screen instantly ?" user sees', 'screen instantly - user sees')
ai_content = ai_content.replace('"?"? OPTIMISTIC UPDATE', 'OPTIMISTIC UPDATE')
ai_content = ai_content.replace('"?"? BACKGROUND SAVE', 'BACKGROUND SAVE')

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(ai_content)

# 4. Fix weekly_report_screen.dart Lottie issue
with open('lib/features/analytics/presentation/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    analytics = f.read()

# Replace Lottie.network with errorBuilder
analytics = analytics.replace(
'''                ? Lottie.network(
                    state.lottieAnimationUrl,
                    fit: BoxFit.cover,
                  )''',
'''                ? Lottie.network(
                    state.lottieAnimationUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, color: AppTheme.accent, size: 40),
                  )'''
)

with open('lib/features/analytics/presentation/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(analytics)

print("Fixes applied.")
