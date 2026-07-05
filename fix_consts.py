import re

with open('lib/features/analytics/presentation/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Specifically fix the lines that have 'const' before something using AppTheme
content = content.replace("const Scaffold(", "Scaffold(")
content = content.replace("const Center(", "Center(")
content = content.replace("const Text('Analisis Mingguan'", "Text('Analisis Mingguan'")
content = content.replace("const IconThemeData(", "IconThemeData(")
content = content.replace("const Text('AI Coach'", "Text('AI Coach'")
content = content.replace("const TextStyle(color: AppTheme.textPrimary", "TextStyle(color: AppTheme.textPrimary")
content = content.replace("const TextStyle(color: AppTheme.textMuted", "TextStyle(color: AppTheme.textMuted")
content = content.replace("const Icon(Icons.chevron_left", "Icon(Icons.chevron_left")
content = content.replace("const Icon(Icons.chevron_right", "Icon(Icons.chevron_right")
content = content.replace("const Text('Volume Latihan (Bulan Ini)'", "Text('Volume Latihan (Bulan Ini)'")

with open('lib/features/analytics/presentation/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# Also fix the unused import in bloc
with open('lib/features/analytics/bloc/analytics_bloc.dart', 'r', encoding='utf-8') as f:
    bloc_content = f.read()
bloc_content = bloc_content.replace("import '../../../services/profile_service.dart';\n", "")
with open('lib/features/analytics/bloc/analytics_bloc.dart', 'w', encoding='utf-8') as f:
    f.write(bloc_content)

print("Fixed constants and imports!")
