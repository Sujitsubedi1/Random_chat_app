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
  bool _showStrangerLeft = false;

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
    setState(() {
      _showStrangerLeft = false;
    });

    final tempUserName = await TempUserManager.getOrCreateTempUsername();
    await firestoreService.joinWaitingQueue(tempUserName, tempUserName);
    await firestoreService.matchUsers();

    String? matchedRoomId;

    for (int i = 0; i < 10; i++) {
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

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    if (matchedRoomId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  ChatScreen(chatRoomId: matchedRoomId!, userId: tempUserName),
        ),
      ).then((result) {
        if (result == 'stranger_left') {
          setState(() {
            _showStrangerLeft = true;
          });
        }
      });
    } else {
      await FirebaseFirestore.instance
          .collection('waitingQueue')
          .doc(tempUserName)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No stranger available. Try again later."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
            if (_showStrangerLeft) ...[
              const Text(
                "Stranger left the chat.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Find Again"),
                onPressed: _onStartChatPressed,
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _onStartChatPressed,
                child: const Text('Start Chat'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
