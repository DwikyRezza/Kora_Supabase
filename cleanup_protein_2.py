import re

# 1. home_screen.dart
with open('lib/features/home/presentation/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    screen_content = f.read()
# Remove List<ProteinEntry> get _todayProtein => state.todayProtein;
screen_content = re.sub(r'  List<ProteinEntry> get _todayProtein => state\.todayProtein;\n', '', screen_content)
# Remove ProteinEntry imports if any
screen_content = re.sub(r"import '.*?protein_entry\.dart';\n", "", screen_content)
with open('lib/features/home/presentation/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(screen_content)

# 2. home_bloc.dart
with open('lib/features/home/bloc/home_bloc.dart', 'r', encoding='utf-8') as f:
    bloc_content = f.read()
bloc_content = re.sub(r'\s*todayProtein: protein,\n', '\n', bloc_content)
bloc_content = re.sub(r'\s*todayProtein: pm\.todayProtein \?\? \[\],\n', '\n', bloc_content)
# just in case
bloc_content = re.sub(r'todayProtein: .*?,\n', '', bloc_content)
with open('lib/features/home/bloc/home_bloc.dart', 'w', encoding='utf-8') as f:
    f.write(bloc_content)

# 3. ai_nutrition_screen.dart
with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    ai_content = f.read()
# The AI screen analyzes food and tries to save ProteinEntry
# We can just mock the save process or remove it.
# It currently has: final entries = results.map((r) => ProteinEntry(...
# We can replace the whole block that saves to DB.
ai_content = re.sub(r'final entries = results\.map\(\(r\) => ProteinEntry\(.*?\)\)\.toList\(\);\n', '', ai_content, flags=re.DOTALL)
# The save button usually shows a success message. We can just pop it.
with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(ai_content)

# 4. splash_screen.dart
with open('lib/screens/splash_screen.dart', 'r', encoding='utf-8') as f:
    splash_content = f.read()
# Future.wait([ ... .getProteinEntriesByDate(today) ])
# We need to just fix the Future.wait so it doesn't have trailing commas or type issues
splash_content = re.sub(r'\.getProteinEntriesByDate\(today\)', '', splash_content)
# let's just rewrite the Future.wait in splash screen safely
# Typically: await Future.wait([ _db.getWorkoutsByDate(today) ... ])
# Wait, splash_content might have empty list or something.
splash_content = splash_content.replace('''    await Future.wait([
          .getProteinEntriesByDate(today)
    ]);''', '') # This might be mangled.
with open('lib/screens/splash_screen.dart', 'w', encoding='utf-8') as f:
    f.write(splash_content)

# 5. home_state.dart
with open('lib/features/home/bloc/home_state.dart', 'r', encoding='utf-8') as f:
    state_content = f.read()
state_content = re.sub(r'  double get totalProteinToday => todayProtein\.fold\(.*?\);\n', '  double get totalProteinToday => 0.0;\n', state_content)
with open('lib/features/home/bloc/home_state.dart', 'w', encoding='utf-8') as f:
    f.write(state_content)

print("Cleanup 2 complete")
