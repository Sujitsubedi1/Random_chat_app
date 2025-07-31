import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'home_container_page.dart';
import 'searching_screen.dart';
import 'package:logger/logger.dart';
import '../services/bot_responder.dart';
import '../constants/banned_keywords.dart';
import 'dart:async';
import '../ads/banner_ad_widget.dart';

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
  Timer? _botReplyTimer;
  String? _lastUserMessage;

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
    if (widget.isBot) {
      // Just redirect to SearchingScreen again (bot or real match will be handled there)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SearchingScreen(userId: widget.userId),
        ),
      );
      return;
    }

    // For real user chat
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

    // Navigate to searching screen
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SearchingScreen(userId: widget.userId)),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final lower = text.toLowerCase();
    final containsBanned = bannedKeywords.any((word) => lower.contains(word));

    if (containsBanned) {
      setState(() {
        _botMessages.add({
          'text':
              "❌ Please keep the conversation respectful. Inappropriate behavior will lead to removal.",
          'sender': 'system',
        });
      });

      await FirebaseFirestore.instance.collection('bannedUsers').add({
        'userId': widget.userId,
        'chatRoomId': widget.chatRoomId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return;
    }

    setState(() {
      _botMessages.add({'text': text, 'sender': widget.userId});
    });

    _controller.clear();

    if (widget.isBot) {
      _lastUserMessage = text;

      // Cancel any previously scheduled reply
      _botReplyTimer?.cancel();

      // Debounce + human delay (3 to 10 seconds)
      final delay = Duration(
        seconds: 3 + (DateTime.now().millisecondsSinceEpoch % 8),
      );

      _botReplyTimer = Timer(delay, () {
        final reply = BotResponder.getReply(_lastUserMessage!);
        setState(() {
          _botMessages.add({'text': reply, 'sender': 'bot'});
        });
      });

      return;
    }

    // Real user chat
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
            Image.asset('assets/images/sad_emoji.png', height: 120),
            const SizedBox(height: 20),
            const Text(
              "Oops! Stranger left the chat 😕",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Want to find someone new?",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.normal, // Not bold
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                "Find Again",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text inside
                ),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchingScreen(userId: widget.userId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent, // Match Start Chat
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
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
    final scaffold = Scaffold(
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
          onPressed: () {
            if (widget.isBot) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeContainerPage(initialIndex: 0),
                ),
              );
            } else {
              _handleExitChat();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: 'Next',
            onPressed: _handleNextUser,
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
                                margin: const EdgeInsets.symmetric(vertical: 4),
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
          const BannerAdWidget(), // 👈 This shows the test banner ad
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildMessageInput(),
          ),
        ],
      ),
    );

    // Wrap only if it's a real user chat
    if (!widget.isBot) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleExitChat();
        },
        child: scaffold,
      );
    } else {
      return scaffold;
    }
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
    _botReplyTimer?.cancel(); // clean up
    super.dispose();
  }
}
