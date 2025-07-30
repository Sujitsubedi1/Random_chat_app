import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'home_container_page.dart';
import 'searching_screen.dart';
import 'package:logger/logger.dart';
import '../services/bot_responder.dart';

final Logger _logger = Logger();

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String userId;
  final bool isBot;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.userId,
    this.isBot = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService firestoreService = FirestoreService();
  String? _strangerId;
  late TextEditingController _controller;
  List<Map<String, String>> _botMessages = [];

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

  void _handleExitChat() async {
    final chatRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId);

    // Mark the chat as inactive and set the leaver
    await chatRef.update({'isActive': false, 'leaver': widget.userId});

    // Delete all messages
    final messagesRef = chatRef.collection('messages');
    final messagesSnapshot = await messagesRef.get();
    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Wait a moment to ensure all messages are deleted
    await Future.delayed(const Duration(milliseconds: 500));

    // Delay full chatRoom deletion by 30 seconds (for User B)
    Future.delayed(const Duration(seconds: 30), () async {
      final updatedChatDoc = await chatRef.get();
      if (updatedChatDoc.exists) {
        final data = updatedChatDoc.data();
        if (data?['isActive'] == false) {
          await chatRef.delete();
        }
      }
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeContainerPage(initialIndex: 0),
      ),
    );
  }

  void _handleNextUser() async {
    final chatRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId);

    // Mark chat as inactive and set leaver
    await chatRef.update({'isActive': false, 'leaver': widget.userId});

    // Delete messages
    final messagesRef = chatRef.collection('messages');
    final messagesSnapshot = await messagesRef.get();
    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delay full room deletion (for the other user to see "Stranger left")
    Future.delayed(const Duration(seconds: 30), () async {
      final updated = await chatRef.get();
      if (updated.exists && updated.data()?['isActive'] == false) {
        await chatRef.delete();
      }
    });

    // Navigate to searching screen to find new user (or fallback to bot)
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SearchingScreen(userId: widget.userId)),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _botMessages.add({'text': text, 'sender': widget.userId});
    });

    _controller.clear();

    // 🔁 If bot mode, respond directly
    if (widget.isBot) {
      final reply = BotResponder.getReply(text);
      await Future.delayed(
        const Duration(milliseconds: 800),
      ); // Fake typing delay

      setState(() {
        _botMessages.add({'text': reply, 'sender': 'bot'});
      });

      return;
    }

    // 🔁 Normal user-to-user message logic
    final newMessage = {
      'text': text,
      'sender': widget.userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add(newMessage);
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
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: 'Next',
              onPressed: _handleNextUser, // We'll define this in Step 2
            ),
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
              child:
                  widget.isBot
                      ? ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _botMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _botMessages[index];
                          final isMe = msg['sender'] == widget.userId;

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isMe
                                        ? const Color(0xFFD2ECFF)
                                        : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg['text'] ?? ''),
                            ),
                          );
                        },
                      )
                      : StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('chatRooms')
                                .doc(widget.chatRoomId)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final msg =
                                  docs[index].data() as Map<String, dynamic>;
                              final sender = msg['sender'] ?? '';
                              final isMe = sender == widget.userId;

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
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe
                                            ? const Color(0xFFD2ECFF)
                                            : const Color(0xFFF0F0F0),
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBot) {
      return _buildChatScaffold();
    }

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
          return const Center(
            child: Text(
              "Room data missing",
              style: TextStyle(color: Colors.red, fontSize: 24),
            ),
          );
        }

        final isActive = data['isActive'] ?? false;
        final leaver = data['leaver'] ?? '';
        final blockerId = data['blocker'];
        final iWasBlocked = blockerId != null && blockerId != widget.userId;

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
