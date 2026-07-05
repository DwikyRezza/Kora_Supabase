import re

with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the pop logic with clearing the form and showing a success message
old_pop = '''    if (!mounted) return;
    Navigator.pop(context, true);'''

new_pop = '''    if (!mounted) return;
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

content = content.replace(old_pop, new_pop)

# Also fix the back button in AppBar
old_back = '''        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),'''

new_back = '''        // Hide back button since it's a tab
        automaticallyImplyLeading: false,'''

content = content.replace(old_back, new_back)

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
