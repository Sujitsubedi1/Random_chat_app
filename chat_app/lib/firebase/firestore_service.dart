import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../constants/usernames.dart';

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final logger = Logger();

  /// ➕ Adds a user to the waitingQueue with a timestamp
  Future<void> joinWaitingQueue(String tempUserId, String tempUserName) async {
    logger.i("➕ Adding $tempUserId to waitingQueue");

    await FirebaseFirestore.instance
        .collection('waitingQueue')
        .doc(tempUserId)
        .set({
          'joinedAt': FieldValue.serverTimestamp(),
          'tempUserName': tempUserName,
        });
  }

  /// 🤝 Matches two users and creates a chatRoom
  Future<void> matchUsers() async {
    final queue = FirebaseFirestore.instance.collection('waitingQueue');

    final snapshot = await queue.orderBy('joinedAt').limit(2).get();

    if (snapshot.docs.length < 2) {
      logger.w("⏳ Not enough users in queue to match.");
      return;
    }

    final user1 = snapshot.docs[0];
    final user2 = snapshot.docs[1];
    logger.i("👥 Attempting to match: ${user1.id} and ${user2.id}");

    // 🔍 Check if either user is already in an active room
    final existingRoom =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .where('isActive', isEqualTo: true)
            .where('users', arrayContainsAny: [user1.id, user2.id])
            .get();

    if (existingRoom.docs.isNotEmpty) {
      logger.w(
        "🚫 Skipping match. ${user1.id} or ${user2.id} already in room.",
      );

      // 🧹 Attempt to delete both from queue regardless
      await _safeDelete(queue, user1.id);
      await _safeDelete(queue, user2.id);
      return;
    }

    // ✅ Safe to match
    final chatRoom = await FirebaseFirestore.instance
        .collection('chatRooms')
        .add({
          'createdAt': FieldValue.serverTimestamp(),
          'users': [user1.id, user2.id],
          'isActive': true,
        });

    logger.i('✅ Matched ${user1.id} and ${user2.id} into room ${chatRoom.id}');

    // 🧹 Remove from queue now
    await _safeDelete(queue, user1.id);
    await _safeDelete(queue, user2.id);
  }

  /// 🧹 Deletes a user safely from the waitingQueue and logs result
  Future<void> _safeDelete(CollectionReference queue, String userId) async {
    try {
      await queue.doc(userId).delete();
      logger.i("🗑️ Deleted $userId from waitingQueue");
    } catch (e) {
      logger.w("⚠️ Could not delete $userId from waitingQueue: $e");
    }
  }

  /// 🔄 Picks a unique username not already in use
  Future<String?> getAvailableUsername() async {
    final usedNames = <String>{};

    // 👥 Check waiting queue
    final waitingSnapshot =
        await FirebaseFirestore.instance.collection('waitingQueue').get();

    for (var doc in waitingSnapshot.docs) {
      usedNames.add(doc.data()['tempUserName']);
    }

    // 💬 Check chatRooms
    final chatSnapshot =
        await FirebaseFirestore.instance.collection('chatRooms').get();

    for (var doc in chatSnapshot.docs) {
      final users = doc.data()['users'] ?? [];
      usedNames.addAll(List<String>.from(users));
    }

    // 🎯 Pick the first unused name
    for (var name in predefinedUsernames) {
      if (!usedNames.contains(name)) {
        return name;
      }
    }

    return null; // all usernames are taken
  }
}
