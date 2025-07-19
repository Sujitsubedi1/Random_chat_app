// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'home_container_page.dart';
import 'searching_screen.dart';
import 'package:logger/logger.dart';
// import 'package:lottie/lottie.dart';
import '../services/chat_services.dart';
// import '../services/temp_user_manager.dart';

final Logger _logger = Logger();

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String userId;

  const ChatScreen({super.key, required this.chatRoomId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService firestoreService = FirestoreService();
  String? _strangerId;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _identifyStranger();
  }

  void _identifyStranger() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['users'] is List) {
        final users = List<String>.from(data['users']);
        final stranger = users.firstWhere(
          (id) => id != widget.userId,
          orElse: () => 'Unknown',
        );
        setState(() {
          _strangerId = stranger;
        });
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
        .update({'leaver': widget.userId, 'isActive': false});

    await ChatService.scheduleRoomCleanup(widget.chatRoomId);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeContainerPage(initialIndex: 0),
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();

    final data = doc.data();
    final blockerId = data?['blocker'];
    final iWasBlocked = blockerId != null && blockerId != widget.userId;
    final iBlocked = blockerId == widget.userId;

    if (iWasBlocked || iBlocked) {
      _logger.w("🚫 Message blocked — cannot send.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can’t send messages in a blocked chat."),
        ),
      );
      return;
    }

    final messageData = {
      'text': text,
      'sender': widget.userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add(messageData);

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .update({
          'lastMessage': text,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
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

  Widget _buildStrangerLeftScreen() {
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
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchingScreen(userId: widget.userId),
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

  Widget _buildBlockedScreen() {
    return HomeContainerPage(
      overrideBody: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("You have blocked this user.", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
      initialIndex: 0,
    );
  }

  Widget _buildIWasBlockedScreen() {
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
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchingScreen(userId: widget.userId),
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

  Widget _buildChatScaffold() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleExitChat();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueGrey,
                child: Text(
                  (_strangerId?.isNotEmpty ?? false)
                      ? _strangerId![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _strangerId ?? "Unknown",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExitChat,
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              elevation: 6,
              itemBuilder:
                  (context) => [
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: const [
                          Icon(Icons.flag, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text("Report User"),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: const [
                          Icon(Icons.block, color: Colors.grey),
                          SizedBox(width: 10),
                          Text("Block User"),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'report') {
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text("Report User"),
                          content: const Text(
                            "Are you sure you want to report this user?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("User reported (UI only)."),
                                  ),
                                );
                              },
                              child: const Text("Report"),
                            ),
                          ],
                        ),
                  );
                } else if (value == 'block') {
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text("Block User"),
                          content: const Text(
                            "You will no longer be matched with this user.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context); // close dialog first

                                final currentUserId = widget.userId;
                                final blockedUserId = _strangerId;

                                if (blockedUserId != null) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUserId)
                                      .collection('blockedUsers')
                                      .doc(blockedUserId)
                                      .set({
                                        'blockedAt':
                                            FieldValue.serverTimestamp(),
                                      });

                                  // Mark chat as inactive + log who blocked
                                  await FirebaseFirestore.instance
                                      .collection('chatRooms')
                                      .doc(widget.chatRoomId)
                                      .update({
                                        'isActive': false,
                                        'leaver': currentUserId,
                                        'blocker': currentUserId,
                                      });

                                  if (!mounted) return;

                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const HomeContainerPage(
                                            initialIndex: 0,
                                          ),
                                    ),
                                  );
                                }
                              },
                              child: const Text("Block"),
                            ),
                          ],
                        ),
                  );
                }
              },
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

                      final sender = (msg['sender'] ?? '').toString().trim();
                      final isMe = sender == widget.userId.trim();
                      final rawReactions = msg['reactions'] ?? {};
                      final reactions = Map<String, dynamic>.from(rawReactions);

                      final allEmojis =
                          reactions.values
                              .toSet()
                              .toList(); // show unique emojis only

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                              isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (_) {
                                    final emojis = [
                                      "😂",
                                      "😍",
                                      "😮",
                                      "😢",
                                      "👍",
                                      "❤️",
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 16,
                                        children:
                                            emojis.map((emoji) {
                                              return GestureDetector(
                                                onTap: () async {
                                                  Navigator.pop(context);

                                                  final messageId =
                                                      messages[messages.length -
                                                              1 -
                                                              index]
                                                          .id;
                                                  final messageRef =
                                                      FirebaseFirestore.instance
                                                          .collection(
                                                            'chatRooms',
                                                          )
                                                          .doc(
                                                            widget.chatRoomId,
                                                          )
                                                          .collection(
                                                            'messages',
                                                          )
                                                          .doc(messageId);

                                                  final docSnapshot =
                                                      await messageRef.get();
                                                  final existingReactions = Map<
                                                    String,
                                                    dynamic
                                                  >.from(
                                                    docSnapshot
                                                            .data()?['reactions'] ??
                                                        {},
                                                  );
                                                  final currentReaction =
                                                      existingReactions[widget
                                                          .userId];

                                                  if (currentReaction ==
                                                      emoji) {
                                                    // 👎 User already reacted with the same emoji → remove it
                                                    existingReactions.remove(
                                                      widget.userId,
                                                    );
                                                  } else {
                                                    // 👍 Add or update user's reaction
                                                    existingReactions[widget
                                                            .userId] =
                                                        emoji;
                                                  }

                                                  await messageRef.set({
                                                    'reactions':
                                                        existingReactions,
                                                  }, SetOptions(merge: true));
                                                },

                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    );
                                  },
                                );
                              },

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 4),

                                decoration: BoxDecoration(
                                  color:
                                      isMe
                                          ? Color(0xFFD2ECFF)
                                          : Color(
                                            0xFFF0F0F0,
                                          ), // Greenish for you, light gray for others
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 16),
                                  ),
                                ),

                                child: Text(msg['text'] ?? ''),
                              ),
                            ),

                            // 🧠 Display emojis under the message
                            if (allEmojis.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 6,
                                  children:
                                      allEmojis.map((emoji) {
                                        return Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 16),
                                        );
                                      }).toList(),
                                ),
                              ),
                          ],
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

        final blockerId = data['blocker'];
        final iWasBlocked = blockerId != null && blockerId != widget.userId;
        // 🔒 Immediately stop showing messages if either user blocked
        if (iWasBlocked) {
          return _buildIWasBlockedScreen();
        } else if (blockerId == widget.userId) {
          return _buildBlockedScreen();
        }

        if (_strangerId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (leaver == widget.userId) {
          return const HomeContainerPage(initialIndex: 0);
        }

        final hasLeft = leaver != '' && leaver != widget.userId;

        if (!isActive || hasLeft) {
          _logger.w("🚫 Stranger left — showing requeue UI");
          return _buildStrangerLeftScreen();
        }

        return _buildChatScaffold();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
