// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/firestore_service.dart';
import 'home_container_page.dart';
import 'searching_screen.dart';
import 'package:logger/logger.dart';
import 'package:lottie/lottie.dart';
import '../services/chat_services.dart';

final Logger _logger = Logger();
Map<String, DateTime> _lastFriendRequests = {};

final TextEditingController _controller = TextEditingController();

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String userId;

  final bool fromFriendsTab;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.userId,
    this.fromFriendsTab = false, // ← add this
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService firestoreService = FirestoreService();
  String? _pendingFriendRequestFrom;
  bool _areFriends = false;
  String? _strangerId;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchStrangerIdAndCheckFriendship();
  }

  Future<void> _fetchStrangerIdAndCheckFriendship() async {
    final result = await ChatService.fetchStrangerAndFriendship(
      chatRoomId: widget.chatRoomId,
      currentUserId: widget.userId,
    );

    if (result == null) return;

    setState(() {
      _strangerId = result['stranger'];
      _areFriends = result['isFriend'];
    });

    final chatData = result['chatRoomData'];
    if (_areFriends &&
        (chatData['isActive'] == false ||
            (chatData['leaver'] ?? '').isNotEmpty)) {
      _logger.w("♻️ Reviving chat room...");
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .update({'isActive': true, 'leaver': ''});
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

    // ✅ Even if friends, we must mark leaver if NOT opened from Friends tab
    if (!_areFriends || !widget.fromFriendsTab) {
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .update({'leaver': widget.userId, 'isActive': false});

      if (!_areFriends) {
        await ChatService.scheduleRoomCleanup(widget.chatRoomId);
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeContainerPage(initialIndex: 0),
      ),
    );
  }

  Future<void> _requeueAndRematch() async {
    setState(() => _isSearching = true); // ✅ show animation immediately

    await firestoreService.joinWaitingQueue(widget.userId, widget.userId);
    await firestoreService.matchUsers();

    final newRoomId = await ChatService.findNewMatchForUser(
      widget.userId,
      widget.chatRoomId,
    );

    if (!mounted) return;

    if (newRoomId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(chatRoomId: newRoomId, userId: widget.userId),
        ),
      );
    } else {
      setState(() => _isSearching = false); // ❗ stop animation if no match
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No match found. Try again shortly.")),
      );
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'text': text,
      'sender': widget.userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1. Add message
    FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2. Update last message & timestamp at room level
    FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .update({
          'lastMessage': text,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

    _controller.clear();
  }

  Future<void> _handleFriendRequest() async {
    if (_areFriends || _strangerId == null) return;

    final lastSentTime = _lastFriendRequests[_strangerId!];

    if (lastSentTime != null &&
        DateTime.now().difference(lastSentTime) < const Duration(minutes: 5)) {
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

    _lastFriendRequests[_strangerId!] = DateTime.now();

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

        final blockerId = data['blocker'];
        final iWasBlocked = blockerId != null && blockerId != widget.userId;

        if (iWasBlocked) {
          _logger.w("🚫 I was blocked — redirecting");

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
                          builder:
                              (_) => SearchingScreen(userId: widget.userId),
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
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SearchingScreen(userId: widget.userId),
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

        if (_areFriends && hasLeft && data['leaver'] != widget.userId) {
          _logger.w("👋 Friend left — showing re-search screen");

          return HomeContainerPage(
            overrideBody: Center(
              child:
                  _isSearching
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔄 Lottie animation
                          Lottie.asset(
                            'assets/animations/animation-search.json',
                            height: 200,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Searching for a new partner...",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Your friend left the chat. \nYou can continue chatting via the Friends tab.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text("Find New Partner"),
                            onPressed: () async {
                              setState(() => _isSearching = true);
                              await _requeueAndRematch();
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
                                        content: Text(
                                          "User reported (UI only).",
                                        ),
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
                                    Navigator.pop(
                                      context,
                                    ); // close dialog first

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

                                      // 👇 Mark chat as inactive + log who blocked
                                      await FirebaseFirestore.instance
                                          .collection('chatRooms')
                                          .doc(widget.chatRoomId)
                                          .update({
                                            'isActive': false,
                                            'leaver': currentUserId,
                                            'blocker': currentUserId,
                                          });

                                      if (!mounted) return;

                                      // 👋 Kick the blocker back to home
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
                          final rawReactions = msg['reactions'] ?? {};
                          final reactions = Map<String, dynamic>.from(
                            rawReactions,
                          );

                          final allEmojis =
                              reactions.values
                                  .toSet()
                                  .toList(); // show unique emojis only

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
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
                                                          messages[messages
                                                                      .length -
                                                                  1 -
                                                                  index]
                                                              .id;
                                                      final messageRef =
                                                          FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'chatRooms',
                                                              )
                                                              .doc(
                                                                widget
                                                                    .chatRoomId,
                                                              )
                                                              .collection(
                                                                'messages',
                                                              )
                                                              .doc(messageId);

                                                      final docSnapshot =
                                                          await messageRef
                                                              .get();
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
                                                        existingReactions
                                                            .remove(
                                                              widget.userId,
                                                            );
                                                      } else {
                                                        // 👍 Add or update user's reaction
                                                        existingReactions[widget
                                                                .userId] =
                                                            emoji;
                                                      }

                                                      await messageRef.set(
                                                        {
                                                          'reactions':
                                                              existingReactions,
                                                        },
                                                        SetOptions(merge: true),
                                                      );
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
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isMe
                                              ? Colors.blue[100]
                                              : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
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
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
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
