import re

with open('lib/features/home/presentation/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add TabVisibility listener to HomeScreen
# We need to add 'import 'package:kora/utils/tab_visibility.dart';'
if 'tab_visibility.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../../utils/tab_visibility.dart';")

# Find initState
old_init = '''  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadHomeData());
  }'''

new_init = '''  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadHomeData());
    TabVisibility.instance.activeTabStream.listen((index) {
      if (index == 0 && mounted) {
        context.read<HomeBloc>().add(LoadHomeData());
      }
    });
  }'''

if old_init in content:
    content = content.replace(old_init, new_init)
else:
    print("Warning: Could not find old initState in home_screen.dart")

with open('lib/features/home/presentation/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Home screen updated.")
