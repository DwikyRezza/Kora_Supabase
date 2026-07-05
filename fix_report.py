import re

# Fix weekly_report_screen.dart
with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix the fire emoji corruption
content = content.replace("Text('%'A A', style: TextStyle(fontSize: 40))", "Text('??', style: TextStyle(fontSize: 40))")
# Just in case it looks slightly different:
content = re.sub(r"Text\('.*?', style: TextStyle\(fontSize: 40\)\)", "Text('??', style: TextStyle(fontSize: 40))", content)

# 2. Fix the full page reload
# Find _loadData() and change it to _loadData({bool showLoading = true})
# In _loadData signature
content = content.replace('Future<void> _loadData() async {', 'Future<void> _loadData({bool showLoading = true}) async {')
# In _loadData body
content = content.replace('setState(() => _isLoading = true);', 'if (showLoading) setState(() => _isLoading = true);')
# In chevrons
content = content.replace('_loadData();', '_loadData(showLoading: false);')
# Revert the first init load
content = content.replace('_loadData(showLoading: false);', '_loadData();', 1) # The one in initState

# 3. Fix the Y-axis label misalignment
# Remove the Positioned block and pass yMax/yMid into TrainingVolumeChart maybe?
# Wait, actually, let's just make the Positioned block match the AspectRatio height perfectly, 
# OR let's use rightTitles in TrainingVolumeChart.
# If I use rightTitles in TrainingVolumeChart, I need to modify TrainingVolumeChart to accept a unit string (km/kg) and format it.

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
