with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'screens/ai_nutrition_screen.dart';", "import 'screens/ai_nutrition_screen.dart';\nimport 'screens/protein_screen.dart';")
content = content.replace("const AiNutritionScreen(),", "const ProteinScreen(),")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
