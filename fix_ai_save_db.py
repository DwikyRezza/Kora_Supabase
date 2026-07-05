with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_save = '''    // Build the list of entries to insert
    
    // -- OPTIMISTIC UPDATE ------------------------------------------------
    // Snapshot previous state for rollback
    final pm = PrefetchManager.instance;
    final prevCalories = pm.todayCaloriesConsumed;
    final totalNewCalories = results.fold<double>(0, (s, r) => s + r.calories).toInt();
    pm.todayCaloriesConsumed = (prevCalories ?? 0) + totalNewCalories;

    // Close screen instantly — user sees updated metric on HomeScreen immediately
    if (!mounted) return;
    Navigator.pop(context, true);

    // -- BACKGROUND SAVE (with 10s timeout and rollback on failure) ----------
    BackgroundTaskQueue.instance.enqueue<void>(
      task: () => Future.value(),'''

new_save = '''    // Build the list of entries to insert
    final pm = PrefetchManager.instance;
    final prevCalories = pm.todayCaloriesConsumed;
    final prevProtein = pm.todayProtein;
    
    final totalNewCalories = results.fold<double>(0, (s, r) => s + r.calories).toInt();
    final totalNewProtein = results.fold<double>(0, (s, r) => s + r.protein);
    
    pm.todayCaloriesConsumed = (prevCalories ?? 0) + totalNewCalories;
    pm.todayProtein = (prevProtein ?? 0.0) + totalNewProtein;

    if (!mounted) return;
    Navigator.pop(context, true);

    BackgroundTaskQueue.instance.enqueue<void>(
      task: () async {
        for (var r in results) {
          final entry = ProteinEntry(
            name: r.name,
            protein: r.protein,
            calories: r.calories,
            carbs: r.carbs,
            fat: r.fat,
            fiber: r.fiber,
            sugar: r.sugar,
            salt: r.salt,
            date: now,
            mealType: mealType,
          );
          await db.insertProteinEntry(entry);
        }
      },'''

content = content.replace(old_save, new_save)

# Let's double check if we need to rollback protein too
content = content.replace('pm.todayCaloriesConsumed = prevCalories;', 'pm.todayCaloriesConsumed = prevCalories;\n          pm.todayProtein = prevProtein;')

# We also need to import ProteinEntry in ai_nutrition_screen.dart if it's not imported
if "import '../models/protein_entry.dart';" not in content:
    content = content.replace("import '../theme/app_theme.dart';", "import '../theme/app_theme.dart';\nimport '../models/protein_entry.dart';")

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
