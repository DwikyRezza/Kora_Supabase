import re

with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove the call
call_pattern = r'if \(!widget\.embedMode\) \{\s*SizedBox\(height: 32\),\s*_buildAssistantEvaluation\(\),\s*\}'
# Actually wait, in my previous edit I wrote:
# if (!widget.embedMode) ...[
#   SizedBox(height: 32),
#   _buildAssistantEvaluation(),
# ],
content = re.sub(r'if \(!widget\.embedMode\) \.\.\.\[\s*SizedBox\(height: 32\),\s*_buildAssistantEvaluation\(\),\s*\],', '', content, flags=re.MULTILINE)

# 2. Remove the function definition completely
# Find the start of the function
start_idx = content.find('Widget _buildAssistantEvaluation() {')
if start_idx != -1:
    # Find the end of the function by counting braces
    brace_count = 0
    end_idx = -1
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                end_idx = i + 1
                break
    
    if end_idx != -1:
        # Also remove the comment above it if it exists
        comment = r'// I"A AI"A A 8. Assistant Evaluation (existing) I"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A AI"A A'
        # Just cut the content
        content = content[:start_idx] + content[end_idx:]

with open('lib/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
