import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class TempUserManager {
  static Future<String> getOrCreateTempUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString('tempUserName');

    if (existing != null) return existing;

    const usernames = [
      "PineApple33",
      "MangoManiac",
      "Stranger007",
      "GhostWriter",
      "PixelNinja",
      "SkyWalker",
      "SilentWolf",
      "FunkyMonkey",
      "CoconutKid",
      "AgentX",
    ];

    final random = Random();
    final newName =
        usernames[random.nextInt(usernames.length)] +
        random.nextInt(9999).toString();

    await prefs.setString('tempUserName', newName);
    return newName;
  }

  static Future<void> resetUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tempUserName');
  }
}
