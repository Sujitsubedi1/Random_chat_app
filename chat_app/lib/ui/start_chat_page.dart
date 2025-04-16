import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firestore_service.dart';
import '../services/temp_user_manager.dart';
import 'chat_screen.dart';

class StartChatPage extends StatelessWidget {
  const StartChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // 🌈 Logo Pill
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
                'assets/world_map.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 30),

              // 🧠 Title + Subtitle
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600, // 💡 Slightly bold
                ),
              ),

              const SizedBox(height: 30),

              // 🟣 Start Chat Button
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A56F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    final userId =
                        await TempUserManager.getOrCreateTempUsername();

                    await FirestoreService().joinWaitingQueue(userId, userId);
                    await FirestoreService().matchUsers();

                    for (int i = 0; i < 10; i++) {
                      final rooms =
                          await FirebaseFirestore.instance
                              .collection('chatRooms')
                              .where('users', arrayContains: userId)
                              .where('isActive', isEqualTo: true)
                              .get();

                      if (rooms.docs.isNotEmpty) {
                        final roomId = rooms.docs.first.id;

                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatScreen(
                                  chatRoomId: roomId,
                                  userId: userId,
                                  fromFriendsTab: false,
                                ),
                          ),
                        );
                        return;
                      }

                      await Future.delayed(const Duration(seconds: 1));
                    }

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No match found. Try again shortly."),
                      ),
                    );
                  },
                  child: const Text(
                    "Start Chat",
                    style: TextStyle(
                      color: Colors.white, // ✅ White Text
                      fontSize: 16,
                      fontWeight: FontWeight.bold, // ✅ Bold
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 🎛️ Preferences
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
    );
  }
}
