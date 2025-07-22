import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static Future<void> scheduleRoomCleanup(String roomId) async {
    await Future.delayed(const Duration(minutes: 1));

    final docRef = FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId);
    final docSnap = await docRef.get();

    if (!docSnap.exists || docSnap.data()?['isActive'] == true) return;

    final messagesSnapshot = await docRef.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var msg in messagesSnapshot.docs) {
      batch.delete(msg.reference);
    }

    batch.delete(docRef);
    await batch.commit();
  }

  static Future<String?> findNewMatchForUser(
    String userId,
    String currentRoomId,
  ) async {
    for (int i = 0; i < 10; i++) {
      final rooms =
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .where('users', arrayContains: userId)
              .where('isActive', isEqualTo: true)
              .get();

      if (rooms.docs.isNotEmpty) {
        final matchedRoom = rooms.docs.first;
        if (matchedRoom.id != currentRoomId) {
          return matchedRoom.id;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    return null;
  }
}
