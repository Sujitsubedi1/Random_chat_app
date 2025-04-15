import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'home_container_page.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();
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
  bool _areFriends = false;
  String? _strangerId;

  @override
  void initState() {
    super.initState();
    _fetchStrangerIdAndCheckFriendship();
  }

  Future<void> _fetchStrangerIdAndCheckFriendship() async {
    _logger.w("🔄 Fetching stranger and friendship...");

    final chatDoc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();
    final data = chatDoc.data();
    if (data == null) {
      _logger.w("❌ Chat room doc is null.");
      return;
    }

    final users = List<String>.from(data['users'] ?? []);
    final stranger = users.firstWhere((id) => id != widget.userId);
    setState(() => _strangerId = stranger);
    _logger.w("👤 Stranger: $stranger");

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('friends')
            .doc(stranger)
            .get();
    final isFriend = doc.exists;
    _logger.w("✅ isFriend: $isFriend");

    if (isFriend) {
      setState(() => _areFriends = true);
      if (data['isActive'] == false || (data['leaver'] ?? '').isNotEmpty) {
        _logger.w("♻️ Reviving chat room...");
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .update({'isActive': true, 'leaver': ''});
      }
    }
  }

  Future<void> _handleExitChat() async {
    final chatDoc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();

    final data = chatDoc.data();
    if (data == null) return;

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .update({
          'leaver': widget.userId, // ✅ Always mark the leaver
          'isActive': _areFriends, // ✅ true if friends, false if strangers
        });

    // 🧼 Only cleanup if NOT friends
    if (!_areFriends) {
      scheduleRoomCleanup(widget.chatRoomId);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeContainerPage(initialIndex: 1),
      ),
    );
  }

  Future<void> _requeueAndRematch() async {
    await firestoreService.joinWaitingQueue(widget.userId, widget.userId);
    await firestoreService.matchUsers();

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
    } else {
      Navigator.pop(context, 'stranger_left');
    }
  }

  Future<void> scheduleRoomCleanup(String roomId) async {
    await Future.delayed(const Duration(minutes: 1));
    final docRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId);
    final docSnap = await docRef.get();

    if (!docSnap.exists || docSnap.data()?['isActive'] == true) return;

    final messagesSnapshot = await docRef.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var msg in messagesSnapshot.docs) {
      batch.delete(msg.reference);
    }
    batch.delete(docRef);
    await batch.commit();
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
    if (_areFriends) return;

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

  Future<void> _respondToFriendRequest(
    String requester,
    String response,
  ) async {
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .doc(requester)
          .set({'since': FieldValue.serverTimestamp()});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(requester)
          .collection('friends')
          .doc(widget.userId)
          .set({'since': FieldValue.serverTimestamp()});

      setState(() => _areFriends = true);
    }

    if (!mounted) return;

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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const Center(child: Text("Room data missing"));
        }

        final isActive = data['isActive'] ?? false;
        final leaver = data['leaver'] ?? '';

        // Wait until we fetch friendship info first
        if (_strangerId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasLeft = leaver != '' && leaver != widget.userId;

        // ✅ Restore chat if they're friends but one user left earlier

        // 👇 Only show "Stranger left" if they're NOT friends
        if ((!isActive || hasLeft) && !_areFriends) {
          _logger.w("🚫 Stranger left — showing requeue UI");
          return HomeContainerPage(
            overrideBody: Center(
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
                    onPressed: _requeueAndRematch,
                  ),
                ],
              ),
            ),
            initialIndex: 0,
          );
        }

        if (_areFriends && hasLeft) {
          _logger.w("👋 Friend left — showing fallback friend screen");
          return HomeContainerPage(
            overrideBody: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Your friend left the chat.\nYou can continue chatting via the Friends tab.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group),
                    label: const Text("Go to Friends"),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const HomeContainerPage(initialIndex: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            initialIndex: 0,
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleExitChat();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Chat Room"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleExitChat,
              ),
              actions: [
                if (!_areFriends)
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

                          if (msg['type'] == 'friend_response' &&
                              msg['response'] == 'yes') {
                            if (!_areFriends) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _areFriends = true);
                              });
                            }

                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  "You and ${_strangerId ?? 'stranger'} are now friends.",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (msg['type'] == 'friend_request') {
                            final requester = msg['from'];
                            if (!_areFriends &&
                                requester != widget.userId &&
                                _pendingFriendRequestFrom != requester) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(
                                    () => _pendingFriendRequestFrom = requester,
                                  );
                                }
                              });
                            }

                            if (requester == widget.userId && !_areFriends) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    "You sent a friend request to ${_strangerId ?? 'stranger'}.",
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

                          if (msg['type'] == 'friend_response' &&
                              msg['response'] == 'no') {
                            final from = msg['from'];
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  from == widget.userId
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

                          final sender =
                              (msg['sender'] ?? '').toString().trim();
                          final isMe = sender == widget.userId.trim();

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
                if (_pendingFriendRequestFrom != null && !_areFriends)
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
                                setState(
                                  () => _pendingFriendRequestFrom = null,
                                );
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
                                setState(
                                  () => _pendingFriendRequestFrom = null,
                                );
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
