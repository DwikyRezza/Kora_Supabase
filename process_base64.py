import os
import re

lib_dir = r"c:\Kuliah Telkom University\sem 6\APB\athleteSync_app\lib"

# We want to replace common patterns of base64 image parsing with network images.
# Example 1: if (photoUrl.startsWith('data:image')) ...
# Example 2: Image.memory(base64Decode(...))

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Replace block: startsWith('data:image') ... return MemoryImage / Image.memory ...
    content = re.sub(
        r"if\s*\([^)]*\.startsWith\('data:image'\)\)\s*\{[^}]*base64Decode[^}]*\}[^}]*\}",
        "",
        content,
        flags=re.DOTALL
    )

    # Some might be inline ternaries: url.startsWith('data:image') ? Image.memory(...) : Image.network(...)
    content = re.sub(
        r"[a-zA-Z0-9_!.?]+\.startsWith\('data:image'\)\s*\?\s*Image\.memory\([^)]+\)\s*:\s*Image\.network\(([^)]+)\)",
        r"Image.network(\1)",
        content
    )
    
    content = re.sub(
        r"[a-zA-Z0-9_!.?]+\.startsWith\('data:image'\)\s*\?\s*ClipOval\([^)]+Image\.memory\([^)]+\)[^)]+\)\s*:\s*ClipOval\([^)]+Image\.network\(([^)]+)\)[^)]+\)",
        r"ClipOval(child: Image.network(\1, fit: BoxFit.cover))",
        content
    )

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("Done")
