import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firestore_service.dart';
import 'chat_screen.dart';
import 'package:lottie/lottie.dart';
import './home_container_page.dart';

class SearchingScreen extends StatefulWidget {
  final String userId;

  const SearchingScreen({super.key, required this.userId});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _startMatching();
  }

  Future<void> _startMatching() async {
    await FirestoreService().joinWaitingQueue(widget.userId, widget.userId);
    await FirestoreService().matchUsers();

    for (int i = 0; i < 10; i++) {
      if (_isCancelling) return; // if cancelled, stop searching!

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
                (_) => ChatScreen(chatRoomId: roomId, userId: widget.userId),
          ),
        );
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted || _isCancelling) return;

    Navigator.pop(context); // fallback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No match found. Try again shortly.")),
    );
  }

  Future<void> _cancelSearch() async {
    setState(() => _isCancelling = true);

    try {
      await FirebaseFirestore.instance
          .collection('waitingQueue')
          .doc(widget.userId)
          .delete();
    } catch (e) {
      // It's fine if already not in queue
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeContainerPage(initialIndex: 0),
        ),
        (route) => false,
      );
    }
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
            const SizedBox(height: 30),
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
              onPressed: _cancelSearch,
            ),
          ],
        ),
      ),
    );
  }
}
