import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class FriendsPage extends StatefulWidget {
  final String userId;

  const FriendsPage({super.key, required this.userId});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  Future<void> openFriendChat(String friendId) async {
    final query =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .where('users', arrayContains: widget.userId)
            .get();

    final matches =
        query.docs.where((doc) {
          final users = List<String>.from(doc['users'] ?? []);
          return users.contains(friendId);
        }).toList();

    if (!mounted) return;

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No chat room found with this friend.")),
      );
      return;
    }

    final matchedRoom = matches.first;
    final docRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(matchedRoom.id);

    // 👇 Check and reactivate if they are friends
    final isActive = matchedRoom['isActive'] ?? true;
    final leaver = matchedRoom['leaver'] ?? '';

    if (!isActive || leaver != '') {
      await docRef.update({'isActive': true, 'leaver': ''});
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              chatRoomId: matchedRoom.id,
              userId: widget.userId,
              fromFriendsTab: true, // ✅ Key addition
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // no back button
        title: const Text('Friends'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('friends')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = snapshot.data!.docs;

          if (friends.isEmpty) {
            return const Center(child: Text("You have no friends yet."));
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friendId = friends[index].id;

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('chatRooms')
                        .where('users', arrayContains: widget.userId)
                        .snapshots(),
                builder: (context, roomSnapshot) {
                  if (!roomSnapshot.hasData) {
                    return const ListTile(title: Text("Loading chat info..."));
                  }

                  QueryDocumentSnapshot? matchingRoom;

                  for (var doc in roomSnapshot.data!.docs) {
                    final users = List<String>.from(doc['users']);
                    if (users.contains(friendId)) {
                      matchingRoom = doc;
                      break;
                    }
                  }

                  if (matchingRoom == null) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey[100],
                        child: Text(
                          friendId.isNotEmpty ? friendId[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(friendId),
                      subtitle: const Text("No messages yet"),
                      onTap: () => openFriendChat(friendId),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('chatRooms')
                            .doc(matchingRoom.id)
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .snapshots(),
                    builder: (context, messageSnapshot) {
                      if (!messageSnapshot.hasData ||
                          messageSnapshot.data!.docs.isEmpty) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(
                              friendId.isNotEmpty
                                  ? friendId[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(friendId),
                          subtitle: const Text("No messages yet"),
                          onTap: () => openFriendChat(friendId),
                        );
                      }

                      final lastMsg =
                          messageSnapshot.data!.docs.first.data()
                              as Map<String, dynamic>;
                      final text = lastMsg['text'] ?? '';
                      final timestamp = lastMsg['timestamp']?.toDate();
                      final time =
                          timestamp != null
                              ? "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}"
                              : '';

                      final isMe = lastMsg['sender'] == widget.userId;
                      final delivered = lastMsg['delivered'] == true;

                      final seenIcon = Icon(
                        Icons.done_all,
                        size: 18,
                        color: delivered ? Colors.blueAccent : Colors.grey,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey[100],
                          child: Text(
                            friendId.isNotEmpty
                                ? friendId[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(friendId),
                        subtitle: Row(
                          children: [
                            if (isMe) seenIcon,
                            if (isMe) const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isMe ? "You: $text" : text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(time),
                        onTap: () => openFriendChat(friendId),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
