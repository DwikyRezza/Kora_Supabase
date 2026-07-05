with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Start string:
start_str = 'if (_workoutDaysMonth.contains(day))'
# End string:
end_str = "Text(\n                              '\',"

start_idx = content.find(start_str)
end_idx = content.find("Text(\n                              '',")

if start_idx != -1 and end_idx != -1:
    new_code = '''if (_workoutDaysMonth.contains(day))
                              Opacity(
                                opacity: 0.35,
                                child: const Text('??', style: TextStyle(fontSize: 26)),
                              )
                            else if (isSuccess)
                              Opacity(
                                opacity: 0.15,
                                child: const Text('??', style: TextStyle(fontSize: 22)),
                              ),
                            '''
    
    content = content[:start_idx] + new_code + content[end_idx:]

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
