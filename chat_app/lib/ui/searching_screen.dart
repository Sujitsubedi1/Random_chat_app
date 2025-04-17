import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firestore_service.dart';
import 'chat_screen.dart';
import 'package:lottie/lottie.dart';

class SearchingScreen extends StatefulWidget {
  final String userId;

  const SearchingScreen({super.key, required this.userId});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  @override
  void initState() {
    super.initState();
    _startMatching();
  }

  Future<void> _startMatching() async {
    await FirestoreService().joinWaitingQueue(widget.userId, widget.userId);
    await FirestoreService().matchUsers();

    for (int i = 0; i < 10; i++) {
      final rooms =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('users', arrayContains: widget.userId)
              .where('isActive', isEqualTo: true)
              .get();

      if (rooms.docs.isNotEmpty) {
        final roomId = rooms.docs.first.id;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  chatRoomId: roomId,
                  userId: widget.userId,
                  fromFriendsTab: false,
                ),
          ),
        );
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    Navigator.pop(context); // fallback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No match found. Try again shortly.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/animation-search.json',
              height: 240,
            ),
            const SizedBox(height: 20),
            const Text(
              "Searching for a chat partner...",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
