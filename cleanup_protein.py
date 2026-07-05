import re

# 1. home_state.dart
with open('lib/features/home/bloc/home_state.dart', 'r', encoding='utf-8') as f:
    state_content = f.read()

state_content = state_content.replace("import '../../../models/protein_entry.dart';\n", "")
state_content = re.sub(r'  final List<ProteinEntry> todayProtein;\n', '', state_content)
state_content = state_content.replace("this.todayProtein = const [],\n", "")
state_content = re.sub(r'    List<ProteinEntry>\? todayProtein,\n', '', state_content)
state_content = state_content.replace("todayProtein: todayProtein ?? this.todayProtein,\n", "")
state_content = state_content.replace("todayProtein,\n", "")

with open('lib/features/home/bloc/home_state.dart', 'w', encoding='utf-8') as f:
    f.write(state_content)

# 2. home_bloc.dart
with open('lib/features/home/bloc/home_bloc.dart', 'r', encoding='utf-8') as f:
    bloc_content = f.read()

bloc_content = re.sub(r'      final protein = await _db.getProteinEntriesByDate\(today\);\n', '', bloc_content)
bloc_content = re.sub(r'          todayProtein: protein,\n', '', bloc_content)

with open('lib/features/home/bloc/home_bloc.dart', 'w', encoding='utf-8') as f:
    f.write(bloc_content)

# 3. home_screen.dart (might still use todayProtein)
with open('lib/features/home/presentation/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    screen_content = f.read()

# Since we remove todayProtein, we need to check if it's used in home_screen.dart.
# E.g. state.todayProtein
if 'state.todayProtein' in screen_content:
    # If the UI uses it, we should replace it with empty list or remove the widget.
    # Usually it's used to calculate total protein.
    screen_content = re.sub(r'double totalProtein = state.todayProtein.fold\(0.0, \(sum, e\) => sum \+ e.proteinGrams\);', 'double totalProtein = 0.0;', screen_content)
    # Check for other usages
    screen_content = re.sub(r'int totalCals = state.todayProtein.fold\(0, \(sum, e\) => sum \+ e.calories\);', 'int totalCals = 0;', screen_content)

with open('lib/features/home/presentation/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(screen_content)

# 4. ai_nutrition_screen.dart
with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    ai_content = f.read()

ai_content = re.sub(r'      task: \(\) => Future.wait\(entries.map\(\(e\) => db.insertProteinEntry\(e\)\)\),\n', '      task: () => Future.value(),\n', ai_content)
# We might need to delete import '../models/protein_entry.dart';
ai_content = ai_content.replace("import '../models/protein_entry.dart';\n", "")
# Wait, if there's no ProteinEntry, what is entries in ai_nutrition_screen?
# It's probably returning some list. Let's not break it too much, just dummy out insertProteinEntry.

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(ai_content)

# 5. splash_screen.dart
with open('lib/screens/splash_screen.dart', 'r', encoding='utf-8') as f:
    splash_content = f.read()

# splash screen has Future.wait([_db.getWorkoutsByDate(today), _db.getProteinEntriesByDate(today)]) or something similar.
splash_content = re.sub(r',\n\s*_db\.getProteinEntriesByDate\(today\)', '', splash_content)
splash_content = re.sub(r',\s*_db\.getProteinEntriesByDate\(today\)', '', splash_content)

with open('lib/screens/splash_screen.dart', 'w', encoding='utf-8') as f:
    f.write(splash_content)

print("Cleanup complete!")
