import 'package:cloud_firestore/cloud_firestore.dart';

class InviteService {
  final _invites = FirebaseFirestore.instance.collection("game_invites");

  Future<void> sendInvite({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
  }) async {
    final existing = await _invites
        .where("fromUid", isEqualTo: fromUid)
        .where("toUid", isEqualTo: toUid)
        .where("status", isEqualTo: "pending")
        .get();

    if (existing.docs.isNotEmpty) {
      return;
    }
    await _invites.add({
      "fromUid": fromUid,
      "fromName": fromName,
      "toUid": toUid,
      "toName": toName,
      "status": "pending",
      "roomId": null,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingInvites(String uid) {
    return _invites
        .where("toUid", isEqualTo: uid)
        .where("status", isEqualTo: "pending")
        .snapshots();
  }

  Future<void> rejectInvite(String inviteId) async {
    await _invites.doc(inviteId).update({"status": "rejected"});
  }

  Future<void> cancelInvite(String inviteId) async {
    await _invites.doc(inviteId).update({"status": "cancelled"});
  }

  Future<void> acceptInvite({
    required String inviteId,
    required String roomId,
  }) async {
    await _invites.doc(inviteId).update({
      "status": "accepted",
      "roomId": roomId,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sentInviteAccepted(String uid) {
    return _invites
        .where("fromUid", isEqualTo: uid)
        .where("status", isEqualTo: "accepted")
        .snapshots();
  }

  Future<void> markInviteHandled(String inviteId) async {
    await _invites.doc(inviteId).delete();
  }
}
