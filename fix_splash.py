import re

with open('lib/screens/splash_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_block = '''      db
          
          .then((v) => pm.todayProtein = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getProteinEntriesByDate gagal: \');
        return [];
      }),'''

bad_block_2 = '''      db
          .then((v) => pm.todayProtein = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getProteinEntriesByDate gagal: \');
        return [];
      }),'''

# Using regex with wildcard for spacing
content = re.sub(r'      db\s*\.then\(\(v\) => pm\.todayProtein = v\)\s*\.catchError\(\(e\) \{\s*debugPrint\(\'\[Prefetch Error\] getProteinEntriesByDate gagal: \S+\'\);\s*return \[\];\s*\}\),', '', content, flags=re.DOTALL)

with open('lib/screens/splash_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
