import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import '../services/temp_user_manager.dart';

class StartChatPage extends StatefulWidget {
  const StartChatPage({super.key});

  @override
  State<StartChatPage> createState() => _StartChatPageState();
}

class _StartChatPageState extends State<StartChatPage> {
  final FirestoreService firestoreService = FirestoreService();

  String? _tempUserName;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await TempUserManager.getOrCreateTempUsername();
    setState(() {
      _tempUserName = name;
    });
  }

  Future<void> _onStartChatPressed() async {
    final navigator = Navigator.of(context);

    final tempUserName = await TempUserManager.getOrCreateTempUsername();

    await firestoreService.joinWaitingQueue(tempUserName, tempUserName);
    await firestoreService.matchUsers();

    // Wait and poll chatRooms to check if this user got matched
    String? matchedRoomId;

    for (int i = 0; i < 10; i++) {
      // try for 10 seconds max
      final rooms =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('users', arrayContains: tempUserName)
              .where('isActive', isEqualTo: true)
              .get();

      if (rooms.docs.isNotEmpty) {
        matchedRoomId = rooms.docs.first.id;
        break;
      }

      await Future.delayed(const Duration(seconds: 1)); // wait before retrying
    }

    if (!mounted) return;

    if (matchedRoomId != null) {
      navigator.push(
        MaterialPageRoute(
          builder:
              (context) =>
                  ChatScreen(chatRoomId: matchedRoomId!, userId: tempUserName),
        ),
      );
    } else {
      // 🧼 Remove user from queue because match failed
      // ✅ Grab context-based tools safely
      final messenger = ScaffoldMessenger.of(context);

      await FirebaseFirestore.instance
          .collection('waitingQueue')
          .doc(tempUserName)
          .delete();
      messenger.showSnackBar(
        const SnackBar(
          content: Text("No stranger available. Try again later."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anonymous Chat')),

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tempUserName != null) ...[
              Text(
                "You are: $_tempUserName",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: _onStartChatPressed,
              child: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
