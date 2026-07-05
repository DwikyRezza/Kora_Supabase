import re

with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Text('??', style: TextStyle(fontSize: 26))", "Text('??', style: TextStyle(fontSize: 26))")
content = content.replace("Text('??', style: TextStyle(fontSize: 22))", "Text('??', style: TextStyle(fontSize: 22))")

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
