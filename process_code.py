import os

def process(path, func):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    new_content = func(content)
    if content != new_content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {path}")

def f_schedule(c):
    c = c.replace('String get typeEmoji {', 'IconData get typeIcon {')
    c = c.replace("return '💪';", "return Icons.fitness_center;")
    c = c.replace("return '🍽️';", "return Icons.restaurant;")
    c = c.replace("return '😴';", "return Icons.bed;")
    c = c.replace("return '🔔';", "return Icons.notifications;")
    c = c.replace("return '📌';", "return Icons.push_pin;")
    c = c.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/material.dart';")
    return c
process('lib/models/schedule_event.dart', f_schedule)

def f_workout(c):
    c = c.replace('String get typeEmoji {', 'IconData get typeIcon {')
    c = c.replace("return '🏃';", "return Icons.directions_run;")
    c = c.replace("return '🏀';", "return Icons.sports_basketball;")
    c = c.replace("return '🏋️';", "return Icons.fitness_center;")
    c = c.replace("return '💪';", "return Icons.sports_gymnastics;")
    if "import 'package:flutter/material.dart';" not in c:
        c = "import 'package:flutter/material.dart';\n" + c
    return c
process('lib/models/workout.dart', f_workout)

def f_protein(c):
    import re
    # Change get mealEmoji and get foodEmoji
    c = re.sub(r'String get mealEmoji \{.*?\}', 
        '''IconData get mealIcon {
    switch (mealType) {
      case 'breakfast': return Icons.wb_twilight;
      case 'lunch': return Icons.wb_sunny;
      case 'dinner': return Icons.nights_stay;
      case 'snack': return Icons.local_dining;
      case 'water': return Icons.local_drink;
      default: return Icons.restaurant;
    }
  }''', c, flags=re.DOTALL)

    c = re.sub(r'String get foodEmoji \{.*?\}', 
        '''IconData get foodIcon {
    return Icons.lunch_dining;
  }''', c, flags=re.DOTALL)
    
    if "import 'package:flutter/material.dart';" not in c:
        c = "import 'package:flutter/material.dart';\n" + c
    return c
process('lib/models/protein_entry.dart', f_protein)

def f_ui(c):
    # This function handles simple text emoji replacements across files
    reps = [
        ("Text(workout.typeEmoji", "Icon(workout.typeIcon, size: 24"),
        ("Text(event.typeEmoji", "Icon(event.typeIcon"),
        ("Text(w.typeEmoji", "Icon(w.typeIcon"),
        ("Text(entry.foodEmoji", "Icon(entry.foodIcon"),
        ("Text(workout.typeEmoji)", "Icon(workout.typeIcon)"),
        
        ("emoji: '🏃'", "icon: Icons.directions_run"),
        ("emoji: '🥗'", "icon: Icons.restaurant"),
        ("emoji: '📅'", "icon: Icons.calendar_today"),
        ("emoji: '💪'", "icon: Icons.fitness_center"),
        # We also need to change the parameter name in home_screen.dart (emoji -> icon: IconData)
        
        # General string emojis
        ("🎉", ""),
        ("🏃", ""),
        ("🏋️", ""),
        ("💪", ""),
        ("🚶", ""),
        ("🔗", ""),
        ("📅", ""),
        ("🍽️", ""),
        ("😴", ""),
        ("🔔", ""),
        ("📌", ""),
        ("🏀", ""),
        ("🥗", ""),
        ("🌙", ""),
        ("☀️", ""),
        ("🔕", ""),
        ("📊", ""),
        ("📏", ""),
        ("📋", ""),
        ("🗓️", ""),
        ("🔥", ""),
        ("👤", ""),
        ("🔄", ""),
        ("🟢", ""),
        ("🔴", ""),
        ("📨", ""),
        ("🚀", ""),
        ("📍", ""),

        ("Lari 7 Hari Terakhir", "Lari 7 Hari Terakhir"), # cleaning any weird spaces if needed
    ]
    for old, new in reps:
        c = c.replace(old, new)

    return c

# apply f_ui to all dart files
for root, _, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart') and f not in ['schedule_event.dart', 'workout.dart', 'protein_entry.dart']:
            process(os.path.join(root, f), f_ui)
