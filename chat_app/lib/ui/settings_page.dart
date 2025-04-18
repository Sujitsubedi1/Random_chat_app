// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/temp_user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _username = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    final userId = await TempUserManager.getOrCreateTempUsername();

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!mounted) return;

    if (doc.exists && doc.data()!.containsKey('username')) {
      setState(() {
        _username = doc.data()!['username'];
      });
    } else {
      // fallback to local just in case
      setState(() {
        _username = userId;
      });
    }
  }

  void _showEditUsernameDialog(BuildContext context) {
    final TextEditingController usernameController = TextEditingController(
      text: _username,
    );

    final dialogContext = context;

    showDialog(
      context: dialogContext,
      builder:
          (_) => AlertDialog(
            title: const Text("Change Username"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    hintText: "Enter new username",
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Username must contain at least 4 letters and 4 numbers.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newUsername = usernameController.text.trim();

                  // 1️⃣ Check format: At least 4 letters and 4 digits
                  final hasMinLetters =
                      RegExp(r'[a-zA-Z]').allMatches(newUsername).length >= 4;
                  final hasMinDigits =
                      RegExp(r'\d').allMatches(newUsername).length >= 4;

                  if (newUsername.isEmpty || !hasMinLetters || !hasMinDigits) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Username must have at least 4 letters and 4 numbers.",
                        ),
                      ),
                    );
                    return;
                  }

                  // 2️⃣ Check if username already exists in Firestore
                  final existingQuery =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .where('username', isEqualTo: newUsername)
                          .get();

                  if (existingQuery.docs.isNotEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Username already taken. Try something else.",
                        ),
                      ),
                    );
                    return;
                  }

                  final userId =
                      await TempUserManager.getOrCreateTempUsername();

                  // 3️⃣ Update Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .set({'username': newUsername}, SetOptions(merge: true));

                  // 4️⃣ Update local storage
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('tempUserName', newUsername);

                  if (!mounted) return;

                  setState(() {
                    _username = newUsername;
                  });

                  Navigator.pop(dialogContext);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          // Profile Section
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blueGrey[100],
                child: Text(
                  _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditUsernameDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Notifications Section
          const Text(
            "Notifications",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            value: true,
            onChanged: (val) {},
          ),

          const SizedBox(height: 24),

          // Privacy & Safety
          const Text(
            "Privacy & Safety",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Terms of Use"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Child Safety Policy"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          SwitchListTile(
            title: const Text("Allow Friend Requests"),
            value: true,
            onChanged: (val) {},
          ),

          const SizedBox(height: 24),

          // Feedback & Support
          const Text(
            "Feedback & Support",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text("Send Feedback"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Report a Bug"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Rate This App"),
            trailing: const Icon(Icons.star_rate),
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // About
          const Text("About", style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text("App Version"),
            subtitle: const Text("1.0.0"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
