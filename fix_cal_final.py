import re

with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# I will find the exact string to replace. I know the first line is:
# "                          children: ["
# And the line after the block is:
# "                            Text("
# "                              '\',"

start_pattern = r'                          children: \[\n'
end_pattern = r'                            Text\(\n                              \'\\','

# Find indices
start_idx = content.find('                          children: [\\n')
# Wait, let's just use re.sub with DOTALL
pattern = r"                          children: \[\n(.*?)\n                            Text\(\n                              '\',"

new_block = '''                          children: [
                            if (_workoutDaysMonth.contains(day))
                              Opacity(
                                opacity: 0.35,
                                child: const Text('??', style: TextStyle(fontSize: 26)),
                              )
                            else if (isSuccess)
                              // Fallback protein success marker if no workout
                              Opacity(
                                opacity: 0.15,
                                child: const Text('??', style: TextStyle(fontSize: 22)),
                              ),
                            Text(
                              '','''

content = re.sub(pattern, new_block.replace('$', '\\$'), content, flags=re.DOTALL)

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
