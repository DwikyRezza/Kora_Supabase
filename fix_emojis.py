import re

with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the Lottie errorBuilder emoji
content = re.sub(r"Text\('.*?',\s*style:\s*TextStyle\(fontSize:\s*40\)\)", "Text('??', style: TextStyle(fontSize: 40))", content)

# Fix the workout days emoji (fontSize: 26)
content = re.sub(r"Text\('.*?',\s*style:\s*TextStyle\(fontSize:\s*26\)\)", "Text('??', style: TextStyle(fontSize: 26))", content)

# Fix the protein success fallback emoji (fontSize: 22) inside Opacity widget
# Look for Opacity -> child: const Text(..., style: TextStyle(fontSize: 22))
content = re.sub(r"child:\s*const\s*Text\('.*?',\s*style:\s*TextStyle\(fontSize:\s*22\)\)", "child: const Text('??', style: TextStyle(fontSize: 22))", content)

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
