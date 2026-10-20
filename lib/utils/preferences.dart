import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _keyRingtone = 'ringtone_path';
  static const _keyThreshold = 'battery_threshold';

  static const int defaultThreshold = 95;

  static Future<void> saveRingtonePath(String path) async {
    print('Preferences: saveRingtonePath() -> Ringtone path saved.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRingtone, path);
  }

  static Future<String?> loadRingtonePath() async {
    print('Preferences: loadRingtonePath() -> Loading ringtone path.');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRingtone);
  }

  static Future<void> saveThreshold(int value) async {
    if (value < 1 || value > 100) {
      throw ArgumentError.value(value, 'value', 'Threshold must be between 1 and 100.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThreshold, value);
  }

  static Future<int> loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_keyThreshold) ?? defaultThreshold;

    // Guard against an invalid stored value.
    if (value < 1 || value > 100) {
      return defaultThreshold;
    }

    return value;
  }
}
