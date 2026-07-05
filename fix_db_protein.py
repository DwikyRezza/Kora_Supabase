import re

with open('lib/services/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add getProteinEntriesByDate and deleteProteinEntry
methods_to_add = '''
  Future<List<Map<String, dynamic>>> getProteinEntriesByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    return await db.query(
      'protein_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
  }

  Future<void> deleteProteinEntry(int id) async {
    final db = await database;
    await db.delete(
      'protein_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
'''

content = re.sub(r'}\s*$', methods_to_add, content)

# Remove the 'import package:kora/models/protein_entry.dart' from database_helper if it isn't there, 
# wait, getProteinEntriesByDate in original code probably returned List<ProteinEntry>.
# If my new function returns List<Map<String, dynamic>>, protein_screen.dart will fail.
# I need to make it return List<ProteinEntry>
import_str = "import '../models/protein_entry.dart';"
if import_str not in content:
    content = content.replace("import 'package:sqflite/sqflite.dart';", "import 'package:sqflite/sqflite.dart';\n" + import_str)

methods_to_add_typed = '''
  Future<List<ProteinEntry>> getProteinEntriesByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'protein_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((e) => ProteinEntry.fromMap(e)).toList();
  }

  Future<void> deleteProteinEntry(int id) async {
    final db = await database;
    await db.delete(
      'protein_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
'''

content = content.replace(methods_to_add, methods_to_add_typed)

with open('lib/services/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Added getProteinEntriesByDate and deleteProteinEntry to DB.")
