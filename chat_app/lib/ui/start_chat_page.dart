import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firestore_service.dart';
import '../services/temp_user_manager.dart';
import 'chat_screen.dart';
import 'package:lottie/lottie.dart';

class StartChatPage extends StatefulWidget {
  const StartChatPage({super.key});

  @override
  State<StartChatPage> createState() => _StartChatPageState();
}

class _StartChatPageState extends State<StartChatPage> {
  bool _isSearching = false;

  // ✅ Step 1: Add variables for online count
  int _onlineUsers = 0;

  @override
  void initState() {
    super.initState();
    _initializeFakeOnlineCount();
  }

  // ✅ Step 2: Initialize a fake but consistent online count per session
  void _initializeFakeOnlineCount() {
    final now = DateTime.now();

    // Set random number between 200–250 based on second
    _onlineUsers = 200 + (now.second % 51);

    // Update the count every 1 minute
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _onlineUsers = 200 + (DateTime.now().second % 51);
        });
      }
    });
  }

  Future<void> _startChat() async {
    setState(() => _isSearching = true);

    final userId = await TempUserManager.getOrCreateTempUsername();
    await FirestoreService().joinWaitingQueue(userId, userId);
    await FirestoreService().matchUsers();

    bool matched = false;

    for (int i = 0; i < 10; i++) {
      final rooms =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('users', arrayContains: userId)
              .where('isActive', isEqualTo: true)
              .get();

      if (rooms.docs.isNotEmpty) {
        final roomId = rooms.docs.first.id;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatRoomId: roomId, userId: userId),
          ),
        );
        matched = true;
        break;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    // 👇 Only if after 10 seconds no match was found
    if (!matched) {
      try {
        await FirebaseFirestore.instance
            .collection('waitingQueue')
            .doc(userId)
            .delete();
      } catch (e) {
        // If already deleted, ignore
      }

      if (!mounted) return;
      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No match found. Try again shortly.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // 🌈 App Logo Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF5DA8), Color(0xFF8A56F1)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    "Random Chat",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 🌍 Map Image
                Image.asset(
                  'assets/images/world_map.png',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 30),

                // ✨ Title + Subtitle
                const Text(
                  "Real talks. Random people.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Chat freely & stay private.",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ Online users indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      "$_onlineUsers+ users online",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 🔄 Searching Animation or Start Button
                _isSearching
                    ? Column(
                      children: [
                        Lottie.asset(
                          'assets/animations/animation-search.json',
                          height: 180,
                          width: 180,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Finding someone to chat with...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ), // ➡️ Add spacing before cancel button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: const Text("Cancel"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () async {
                            final userId =
                                await TempUserManager.getOrCreateTempUsername();

                            try {
                              await FirebaseFirestore.instance
                                  .collection('waitingQueue')
                                  .doc(userId)
                                  .delete();
                            } catch (e) {
                              // Ignore if not found
                            }

                            if (mounted) {
                              setState(() {
                                _isSearching = false;
                              });
                            }
                          },
                        ),
                      ],
                    )
                    : SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A56F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _isSearching ? null : _startChat,
                        child: const Text(
                          "Start Chat",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                const SizedBox(height: 30),

                // 🎛️ Filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 18),
                        SizedBox(width: 6),
                        Text("All genders"),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.favorite_border, size: 18),
                        SizedBox(width: 6),
                        Text("Any interests"),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
