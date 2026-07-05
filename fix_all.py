import re

# 1. Fix HomeState
with open('lib/features/home/bloc/home_state.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final int todayCaloriesConsumed;',
    'final int todayCaloriesConsumed;\n  final double todayProtein;'
)

content = content.replace(
    'this.todayCaloriesConsumed = 0,',
    'this.todayCaloriesConsumed = 0,\n    this.todayProtein = 0.0,'
)

content = content.replace(
    'double get totalProteinToday => 0.0;',
    'double get totalProteinToday => todayProtein;'
)

content = content.replace(
    'int? todayCaloriesConsumed,',
    'int? todayCaloriesConsumed,\n    double? todayProtein,'
)

content = content.replace(
    'todayCaloriesConsumed: todayCaloriesConsumed ?? this.todayCaloriesConsumed,',
    'todayCaloriesConsumed: todayCaloriesConsumed ?? this.todayCaloriesConsumed,\n      todayProtein: todayProtein ?? this.todayProtein,'
)

content = content.replace(
    'todayCaloriesConsumed,',
    'todayCaloriesConsumed,\n        todayProtein,'
)

with open('lib/features/home/bloc/home_state.dart', 'w', encoding='utf-8') as f:
    f.write(content)


# 2. Fix HomeBloc
with open('lib/features/home/bloc/home_bloc.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('entry.protein;', 'entry.proteinGrams;')
with open('lib/features/home/bloc/home_bloc.dart', 'w', encoding='utf-8') as f:
    f.write(content)


# 3. Fix AiNutritionScreen
with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('name: r.name,', 'foodName: r.name,')
content = content.replace('protein: r.protein,', 'proteinGrams: r.protein,')

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
