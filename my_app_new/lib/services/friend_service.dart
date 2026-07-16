import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  Future<void> sendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
  }) async {
    await FirebaseFirestore.instance.collection("friend_requests").add({
      "fromUid": fromUid,
      "fromName": fromName,
      "toUid": toUid,
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getIncomingRequests(String uid) {
    return FirebaseFirestore.instance
        .collection("friend_requests")
        .where("toUid", isEqualTo: uid)
        .where("status", isEqualTo: "pending")
        .snapshots();
  }

  Future<void> acceptRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
  }) async {
    final db = FirebaseFirestore.instance;

    final batch = db.batch();

    batch.update(db.collection("friend_requests").doc(requestId), {
      "status": "accepted",
    });

    batch.set(
      db.collection("users").doc(fromUid).collection("friends").doc(toUid),
      {"addedAt": FieldValue.serverTimestamp()},
    );

    batch.set(
      db.collection("users").doc(toUid).collection("friends").doc(fromUid),
      {"addedAt": FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  Future<void> rejectRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection("friend_requests")
        .doc(requestId)
        .update({"status": "rejected"});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getFriends(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("friends")
        .snapshots();
  }

  Future<Set<String>> getFriendIds(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("friends")
        .get();

    return snapshot.docs.map((e) => e.id).toSet();
  }

  Future<Set<String>> getSentPendingRequestIds(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("fromUid", isEqualTo: uid)
        .where("status", isEqualTo: "pending")
        .get();

    return snapshot.docs.map((e) => e.data()["toUid"] as String).toSet();
  }

  Future<void> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    final db = FirebaseFirestore.instance;

    final batch = db.batch();

    batch.delete(
      db.collection("users").doc(uid).collection("friends").doc(friendUid),
    );

    batch.delete(
      db.collection("users").doc(friendUid).collection("friends").doc(uid),
    );

    await batch.commit();
  }
}
