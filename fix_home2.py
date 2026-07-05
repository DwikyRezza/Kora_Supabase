with open('lib/features/home/presentation/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the import
content = content.replace("import '../../../utils/tab_visibility.dart';", "import '../../../../utils/tab_visibility.dart';")

# Fix the duplicate dispose
bad_dispose = '''  @override
  void dispose() {
    _tabSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }'''

good_dispose = '''  @override
  void dispose() {
    _tabSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }'''

content = content.replace(bad_dispose, good_dispose)

with open('lib/features/home/presentation/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed home screen again.")
