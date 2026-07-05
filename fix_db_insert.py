import re

with open('lib/services/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add insertProteinEntry method
methods_to_add = '''
  Future<int> insertProteinEntry(ProteinEntry entry) async {
    final db = await database;
    return await db.insert('protein_entries', entry.toMap());
  }
}
'''

content = re.sub(r'}\s*$', methods_to_add, content)

with open('lib/services/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Added insertProteinEntry to DB.")
