import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final String pfShowHelp = "showHelp";

  static Future<bool> setString(String key, String data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, data);
  }

  static Future<String> getString(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
