import re

with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Pass unit
content = content.replace(
'''                child: TrainingVolumeChart(
                  weeklyVolumes: chartValues,''',
'''                child: TrainingVolumeChart(
                  unit: _progressFilter == 'lift' ? 'kg' : 'km',
                  weeklyVolumes: chartValues,'''
)

# Remove Positioned block
# It looks like:
#              // I"A AI"A A Y-axis labels kanan (Tetap ada di luar chart) I"A AI"A A
#              Positioned(
#                right: 0,
#                top: 0,
# ...
#              ),
#            ],
#          ),

start_str = '''              // I"A AI"A A Y-axis labels kanan'''
# just use regex to remove the Positioned block until the next ],
content = re.sub(r'              // (I".*?)? Y-axis labels kanan.*?\n\s*Positioned\([\s\S]*?\n\s*\),\n\s*\],', '              ],\n', content)

# Remove Padding(right: 56) from TrainingVolumeChart wrapper since we don't need to make room for absolute positioned labels anymore
content = content.replace(
'''              Padding(
                padding: EdgeInsets.only(right: 56),
                child: TrainingVolumeChart(''',
'''              Padding(
                padding: EdgeInsets.only(right: 8),
                child: TrainingVolumeChart('''
)

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
