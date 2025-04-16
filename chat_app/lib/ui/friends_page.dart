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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Friends'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('chatRooms')
                .where('users', arrayContains: widget.userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("You have no active chats."));
          }

          final rooms = snapshot.data!.docs;

          // Build friend list from rooms
          final friendsData =
              rooms.map((doc) {
                final users = List<String>.from(doc['users']);
                final friendId = users.firstWhere((u) => u != widget.userId);
                final lastMessage = doc['lastMessage'] ?? '';
                final timestamp = doc['lastMessageTimestamp']?.toDate();
                return {
                  'friendId': friendId,
                  'roomId': doc.id,
                  'lastMessage': lastMessage,
                  'timestamp':
                      timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
                };
              }).toList();

          // Sort by timestamp DESCENDING
          friendsData.sort(
            (a, b) => (b['timestamp'] as DateTime).compareTo(
              a['timestamp'] as DateTime,
            ),
          );

          return ListView.builder(
            itemCount: friendsData.length,
            itemBuilder: (context, index) {
              final friend = friendsData[index];
              final friendId = friend['friendId'];
              final lastMessage = friend['lastMessage'] ?? '';
              final timestamp = friend['timestamp'] as DateTime;
              final time =
                  "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey[100],
                  child: Text(
                    friendId.isNotEmpty ? friendId[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(friendId),
                subtitle: Text(
                  lastMessage.isEmpty ? "No messages yet" : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(time),
                onTap: () => openFriendChat(friendId),
              );
            },
          );
        },
      ),
    );
  }
}
