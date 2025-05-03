import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/usernames.dart'; // ⬅️ now importing from shared list

class TempUserManager {
  static Future<String> getOrCreateTempUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString('tempUserName');

    if (existing != null) return existing;

    final random = Random();
    final newName =
        predefinedUsernames[random.nextInt(predefinedUsernames.length)] +
        random.nextInt(9999).toString();

    await prefs.setString('tempUserName', newName);

    // ✅ Store in Firestore
    final docRef = FirebaseFirestore.instance.collection('users').doc(newName);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({'username': newName, 'createdAt': DateTime.now()});
    }

    return newName;
  }

  static Future<void> resetUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tempUserName');
  }
}
