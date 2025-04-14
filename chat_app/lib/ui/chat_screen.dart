import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
// import 'start_chat_page.dart';
import 'home_container_page.dart';

DateTime? _lastFriendRequestTime;
final TextEditingController _controller = TextEditingController();

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String userId;

  const ChatScreen({super.key, required this.chatRoomId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService firestoreService = FirestoreService();
  String? _pendingFriendRequestFrom;
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
      MaterialPageRoute(builder: (_) => const HomeContainerPage()),
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

  Future<void> _handleFriendRequest() async {
    if (_lastFriendRequestTime != null &&
        DateTime.now().difference(_lastFriendRequestTime!) <
            const Duration(minutes: 5)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already sent a friend request. Try again later.'),
        ),
      );
      return;
    }

    // Send friend request message into chat
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
          'type': 'friend_request',
          'from': widget.userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _lastFriendRequestTime = DateTime.now();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Friend request sent!")));
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

  Future<void> _respondToFriendRequest(
    String requester,
    String response,
  ) async {
    // 1. Log the friend response to chat (optional, for tracking)
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
          'type': 'friend_response',
          'from': widget.userId,
          'response': response,
          'timestamp': FieldValue.serverTimestamp(),
        });

    if (response == 'yes') {
      // 2. Store in current user's friends list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .doc(requester)
          .set({'since': FieldValue.serverTimestamp()});

      // 3. Store in requester’s friends list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requester)
          .collection('friends')
          .doc(widget.userId)
          .set({'since': FieldValue.serverTimestamp()});
    }

    if (!mounted) return;

    // 4. Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response == "yes"
              ? "You are now friends with $requester!"
              : "Friend request ignored.",
        ),
      ),
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
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _requeueAndRematch();
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) {
          return const Center(child: Text("Room data missing"));
        }

        final isActive = data['isActive'] ?? false;
        final leaver = data['leaver'] ?? '';

        if (!isActive) {
          if (leaver == widget.userId) {
            return const SizedBox.shrink();
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text("Chat Room"),
              automaticallyImplyLeading: false,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Stranger left the chat.",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Find Again"),
                    onPressed: () => _requeueAndRematch(),
                  ),
                ],
              ),
            ),
          );
        }

        return PopScope<String>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, String? result) {
            if (!didPop) {
              _handleExitChat();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Chat Room"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleExitChat,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: _handleFriendRequest,
                ),
              ],
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

                          // ✅ Friend request handler
                          if (msg['type'] == 'friend_request') {
                            final requester = msg['from'];
                            final isMe = requester == widget.userId;

                            final hasResponse = messages.any((m) {
                              final mData = m.data() as Map<String, dynamic>;
                              return mData['type'] == 'friend_response' &&
                                  mData['from'] != requester;
                            });

                            if (!isMe &&
                                !hasResponse &&
                                _pendingFriendRequestFrom != requester) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _pendingFriendRequestFrom = requester;
                                  });
                                }
                              });
                            }

                            if (isMe) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6.0,
                                  ),
                                  child: Text(
                                    "You sent a friend request to $requester.",
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          }

                          // ✅ Friend response - accepted
                          if (msg['type'] == 'friend_response' &&
                              msg['response'] == 'yes') {
                            final from = msg['from'];
                            final isMe = from == widget.userId;

                            if (_pendingFriendRequestFrom != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _pendingFriendRequestFrom = null;
                                  });
                                }
                              });
                            }

                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Text(
                                  isMe
                                      ? "You and ${_pendingFriendRequestFrom ?? 'stranger'} are now friends."
                                      : "You and $from are now friends.",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          }

                          // ✅ Friend response - rejected
                          if (msg['type'] == 'friend_response' &&
                              msg['response'] == 'no') {
                            final from = msg['from'];
                            final isMe = from == widget.userId;

                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Text(
                                  isMe
                                      ? "You rejected the friend request."
                                      : "$from rejected your friend request.",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            );
                          }

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

                if (_pendingFriendRequestFrom != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "$_pendingFriendRequestFrom wants to be your friend.",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _respondToFriendRequest(
                                  _pendingFriendRequestFrom!,
                                  'yes',
                                );
                                setState(() {
                                  _pendingFriendRequestFrom = null;
                                });
                              },
                              child: const Text("Yes"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                _respondToFriendRequest(
                                  _pendingFriendRequestFrom!,
                                  'no',
                                );
                                setState(() {
                                  _pendingFriendRequestFrom = null;
                                });
                              },
                              child: const Text("No"),
                            ),
                          ],
                        ),
                      ],
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
