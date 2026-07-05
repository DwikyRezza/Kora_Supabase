import re

with open('lib/services/cloud_sync_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove protein sync method
protein_sync_regex = r"(  static Future<void> syncProteinToCloud.*?)(?=  static Future<void> syncSchedulesToCloud|  static Future<void> backupToCloud)"
content = re.sub(protein_sync_regex, "", content, flags=re.DOTALL)

# Remove its invocation in backupToCloud
backup_invocation_regex = r"await syncProteinToCloud\(\);\s*"
content = re.sub(backup_invocation_regex, "", content)

# Write back
with open('lib/services/cloud_sync_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
