// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  void _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://random-chat-3e819.web.app/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _launchTermsOfUse() async {
    final Uri url = Uri.parse('https://random-chat-3e819.web.app/terms');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          // Profile Section
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
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: _launchPrivacyPolicy,
          ),
          ListTile(
            title: const Text("Terms of Use"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _launchTermsOfUse,
          ),

          ListTile(
            title: const Text("Child Safety Policy"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
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
