with open('lib/screens/workout_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("WeeklyReportScreen(embedMode: true),", "_buildProgressTab(),")

with open('lib/screens/workout_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
