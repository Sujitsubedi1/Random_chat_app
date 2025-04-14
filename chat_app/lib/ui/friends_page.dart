import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FriendsPage extends StatelessWidget {
  final String userId;

  const FriendsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
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
              final since = friends[index]['since']?.toDate();

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(friendId),
                subtitle:
                    since != null
                        ? Text(
                          'Friends since: ${since.toLocal().toString().split('.')[0]}',
                        )
                        : null,
              );
            },
          );
        },
      ),
    );
  }
}
