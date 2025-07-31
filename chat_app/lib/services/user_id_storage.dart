import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../utils/platform_helper.dart'; // ✅ platform-safe check

class UserIdStorage {
  static Future<String> getHashedDeviceId() async {
    String rawId;

    if (kIsWeb) {
      rawId = const Uuid().v4();
    } else {
      final deviceInfo = DeviceInfoPlugin();

      if (isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        rawId = androidInfo.id;
      } else if (isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? "unknown_ios";
      } else {
        rawId = "unknown_device";
      }
    }

    final bytes = utf8.encode(rawId);
    return sha256.convert(bytes).toString();
  }

  static Future<String> getOrCreateTempUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString('hashedDeviceId');

    if (existing != null) return existing;

    final deviceId = await getHashedDeviceId();
    await prefs.setString('hashedDeviceId', deviceId);
    return deviceId;
  }
}
