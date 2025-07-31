import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final logger = Logger();

  /// ➕ Adds a user to the waitingQueue with a timestamp
  Future<void> joinWaitingQueue(String tempUserId, String tempUserName) async {
    final queueRef = FirebaseFirestore.instance
        .collection('waitingQueue')
        .doc(tempUserId);

    // 🔥 Step 1: Remove the user if already in queue
    try {
      await queueRef.delete();
      logger.i("🗑️ Cleaned up old queue entry for $tempUserId");
    } catch (e) {
      logger.w(
        "⚠️ No old entry to delete for $tempUserId (or already deleted): $e",
      );
    }

    // ✅ Step 2: Add fresh entry
    logger.i("➕ Adding $tempUserId to waitingQueue");
    await queueRef.set({
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
    final user1Id = user1.id;
    final user2Id = user2.id;

    logger.i("👥 Attempting to match: $user1Id and $user2Id");

    // 🚫 Check if either user blocked the other
    final block1 =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user1Id)
            .collection('blockedUsers')
            .doc(user2Id)
            .get();

    final block2 =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user2Id)
            .collection('blockedUsers')
            .doc(user1Id)
            .get();

    if (block1.exists || block2.exists) {
      logger.w(
        "🚫 Block detected. Skipping match between $user1Id and $user2Id.",
      );
      await _safeDelete(queue, user1Id);
      await _safeDelete(queue, user2Id);
      return;
    }

    // 🔍 Check if either user is already in an active room
    final existingRoom =
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .where('isActive', isEqualTo: true)
            .where('users', arrayContainsAny: [user1Id, user2Id])
            .get();

    if (existingRoom.docs.isNotEmpty) {
      logger.w("🚫 One of them is already in a room.");
      await _safeDelete(queue, user1Id);
      await _safeDelete(queue, user2Id);
      return;
    }

    // ✅ Proceed with matching
    final newRoomRef = FirebaseFirestore.instance.collection('chatRooms').doc();

    await newRoomRef.set({
      'users': [user1Id, user2Id],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'leaver': '',
    });

    await _safeDelete(queue, user1Id);
    await _safeDelete(queue, user2Id);

    logger.i("✅ Match successful: $user1Id & $user2Id in ${newRoomRef.id}");
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

  Future<void> blockUser(String blockerId, String blockedId) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(blockerId);
    await docRef.set({
      'blockedUsers': FieldValue.arrayUnion([blockedId]),
    }, SetOptions(merge: true));
  }

  Future<void> leaveWaitingQueue(String userId) async {
    logger.w("🔥 leaveWaitingQueue() called for $userId");

    try {
      await FirebaseFirestore.instance
          .collection('waitingQueue')
          .doc(userId)
          .delete();
      logger.w("🗑️ Successfully removed $userId from waitingQueue");
    } catch (e) {
      logger.w("⚠️ Could not remove $userId from waitingQueue: $e");
    }
  }
}
