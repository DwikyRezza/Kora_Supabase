with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Pass unit
content = content.replace('weeklyVolumes: chartValues,', 'unit: _progressFilter == \"lift\" ? \"kg\" : \"km\",\n                weeklyVolumes: chartValues,')

# Remove Positioned block
# Find 'Positioned(' after 'onIndexChanged'
start_idx = content.find('Positioned(', content.find('onIndexChanged'))
# Find the exact closing ']' for the Stack children
end_idx = content.find('            ],\n          ),\n        ),\n      );\n    }')

if start_idx != -1 and end_idx != -1:
    # also remove the comment before Positioned
    comment_idx = content.rfind('//', 0, start_idx)
    content = content[:comment_idx] + content[end_idx:]

# Remove Padding(right: 56)
content = content.replace('padding: EdgeInsets.only(right: 56)', 'padding: EdgeInsets.only(right: 8)')

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
