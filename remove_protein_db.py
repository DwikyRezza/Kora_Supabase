import re

with open('lib/services/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove import
content = re.sub(r"import '\.\./models/protein_entry\.dart';\n", "", content)

# 2. Remove CREATE TABLE protein_entries
create_table_regex = r"await db\.execute\('''\s*CREATE TABLE protein_entries.*?'''\);"
content = re.sub(create_table_regex, "", content, flags=re.DOTALL)

# 3. Remove all protein CRUD methods
# Let's just find where they start and end. Usually they are grouped.
# They look like: Future<int> insertProtein... getTodayProtein... deleteProtein... etc
methods_regex = r"(// -- Protein / Nutrition ------------------------------------------\s*).*?(?=  // -- Measurement ------------------------------------------------)"
content = re.sub(methods_regex, "", content, flags=re.DOTALL)

with open('lib/services/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
