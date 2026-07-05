import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'screens/protein_screen.dart';", "import 'screens/ai_nutrition_screen.dart';")
content = content.replace("const ProteinScreen(),", "const AiNutritionScreen(),")

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)
