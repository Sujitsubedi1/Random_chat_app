import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final String username;

  const SettingsPage({super.key, required this.username});

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
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
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
                        username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
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
