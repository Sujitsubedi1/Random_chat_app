import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'start_chat_page.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String userId;

  const ChatScreen({super.key, required this.chatRoomId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService firestoreService = FirestoreService();

  Future<void> _handleExitChat() async {
    final chatDoc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();

    final data = chatDoc.data();
    if (data == null) return;

    // ✅ Mark chat inactive and log who left
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .update({'isActive': false, 'leaver': widget.userId});

    if (!mounted) return;

    // ✅ Only the user who pressed back exits to home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StartChatPage()),
    );
  }

  Future<void> _requeueAndRematch() async {
    // Step 1: Requeue the user
    await firestoreService.joinWaitingQueue(widget.userId, widget.userId);
    await firestoreService.matchUsers();

    // Step 2: Wait for a new match
    String? newRoomId;

    for (int i = 0; i < 10; i++) {
      final rooms =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('users', arrayContains: widget.userId)
              .where('isActive', isEqualTo: true)
              .get();

      if (rooms.docs.isNotEmpty) {
        final matchedRoom = rooms.docs.first;
        if (matchedRoom.id != widget.chatRoomId) {
          newRoomId = matchedRoom.id;
          break;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    if (newRoomId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(chatRoomId: newRoomId!, userId: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chatRooms')
              .doc(widget.chatRoomId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isActive = data['isActive'] ?? false;
        final leaver = data['leaver'] ?? '';

        if (!isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (leaver == widget.userId) {
              // I’m the one who left → already handled by back button
              return;
            }

            // Stranger left → requeue and try rematching
            await _requeueAndRematch();
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PopScope<String>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, String? result) {
            if (!didPop) {
              _handleExitChat(); // ✅ call your cleanup logic here
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Chat Room"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleExitChat,
              ),
            ),
            body: Center(
              child: Text("You're in chat room: ${widget.chatRoomId}"),
            ),
          ),
        );
      },
    );
  }
}
