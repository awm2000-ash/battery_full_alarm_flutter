import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _keyRingtone = 'ringtone_path';

  static Future<void> saveRingtonePath(String path) async {
    print("Preferences:saveRingtonePath() -> Ringtune is saved...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRingtone, path);
  }

  static Future<String?> loadRingtonePath() async {
    print("Preferences:loadRingtonePath() -> Ringtune path is loaded...");
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRingtone);
  }
}
