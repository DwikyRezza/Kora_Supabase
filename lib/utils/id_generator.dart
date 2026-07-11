import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  /// Generates a v4 UUID (random)
  static String generate() {
    return _uuid.v4();
  }

  /// Parses an ID dynamically from a Map, converting int to String if needed 
  /// (for backwards compatibility during DB migration)
  static String? parseId(dynamic idValue) {
    if (idValue == null) return null;
    return idValue.toString();
  }
}
