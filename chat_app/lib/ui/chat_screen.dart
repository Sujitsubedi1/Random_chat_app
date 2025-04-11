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

    // ✅ Schedule cleanup
    scheduleRoomCleanup(widget.chatRoomId);
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

  Future<void> scheduleRoomCleanup(String roomId) async {
    await Future.delayed(const Duration(minutes: 1));

    final docRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) return;

    final data = docSnap.data();
    if (data == null || data['isActive'] == true) {
      return; // Room active again? Skip.
    }

    // Delete all messages in the subcollection
    final messagesSnapshot = await docRef.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();

    for (var msg in messagesSnapshot.docs) {
      batch.delete(msg.reference);
    }

    // Delete the chatRoom document
    batch.delete(docRef);

    await batch.commit();
    debugPrint("🧹 Deleted inactive room: $roomId");
  }

  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
          'text': text,
          'sender': widget.userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _controller.clear();
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Type a message...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
      ],
    );
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
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // ChatRoom document no longer exists → maybe it was deleted after inactive
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _requeueAndRematch(); // 👈 safely requeue user B
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;
        if (!doc.exists) {
          // already handled above, but safe to recheck here
          return const SizedBox.shrink();
        }
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) {
          return const Center(child: Text("Room data missing"));
        }
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

            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('chatRooms')
                            .doc(widget.chatRoomId)
                            .collection('messages')
                            .orderBy('timestamp')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg =
                              messages[messages.length - 1 - index].data()
                                  as Map<String, dynamic>;
                          final isMe = msg['sender'] == widget.userId;

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.blue[100] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg['text'] ?? ''),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildMessageInput(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
