import os
import glob

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "import 'screens/weekly_report_screen.dart';" in content or "import '../screens/weekly_report_screen.dart';" in content:
        content = content.replace("import 'screens/weekly_report_screen.dart';", "import 'features/analytics/presentation/screens/weekly_report_screen.dart';")
        content = content.replace("import '../screens/weekly_report_screen.dart';", "import '../features/analytics/presentation/screens/weekly_report_screen.dart';")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            replace_in_file(os.path.join(root, file))
