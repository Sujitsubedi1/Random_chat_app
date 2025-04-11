import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../constants//usernames.dart';

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final logger = Logger();

  Future<void> joinWaitingQueue(String tempUserId, String tempUserName) async {
    await FirebaseFirestore.instance
        .collection('waitingQueue')
        .doc(tempUserId)
        .set({
          'joinedAt': FieldValue.serverTimestamp(),
          'tempUserName': tempUserName,
        });
  }

  Future<void> matchUsers() async {
    final queue = FirebaseFirestore.instance.collection('waitingQueue');

    final snapshot = await queue.orderBy('joinedAt').limit(2).get();

    if (snapshot.docs.length < 2) return; // Not enough users yet

    final user1 = snapshot.docs[0];
    final user2 = snapshot.docs[1];

    final chatRoom = await FirebaseFirestore.instance
        .collection('chatRooms')
        .add({
          'createdAt': FieldValue.serverTimestamp(),
          'users': [user1.id, user2.id],
          'isActive': true,
        });

    await queue.doc(user1.id).delete();
    await queue.doc(user2.id).delete();

    logger.i('Matched ${user1.id} and ${user2.id} into room ${chatRoom.id}');
  }

  Future<String?> getAvailableUsername() async {
    final usedNames = <String>{};

    // Get all usernames currently in waitingQueue
    final waitingSnapshot =
        await FirebaseFirestore.instance.collection('waitingQueue').get();

    for (var doc in waitingSnapshot.docs) {
      usedNames.add(doc.data()['tempUserName']);
    }

    // Also check active chat rooms
    final chatSnapshot =
        await FirebaseFirestore.instance.collection('chatRooms').get();

    for (var doc in chatSnapshot.docs) {
      final users = doc.data()['users'] ?? [];
      usedNames.addAll(List<String>.from(users));
    }

    // Pick first unused one
    for (var name in predefinedUsernames) {
      if (!usedNames.contains(name)) {
        return name;
      }
    }

    return null; // all names in use
  }
}
