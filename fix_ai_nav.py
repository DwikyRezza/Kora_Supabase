with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Restore back button
content = content.replace('// Hide back button since it\'s a tab\\n        automaticallyImplyLeading: false,', '''        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),''')
content = content.replace('// Hide back button since it\\'s a tab\\n        automaticallyImplyLeading: false,', '''        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),''')

# Restore pop instead of setState
old_save = '''    if (!mounted) return;
    // Clear form and show success instead of popping (since this is a tab)
    setState(() {
      _results = null;
      _rows.clear();
      _addRow();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nutrisi berhasil dicatat!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );'''

new_save = '''    if (!mounted) return;
    Navigator.pop(context, true);'''

content = content.replace(old_save, new_save)

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
