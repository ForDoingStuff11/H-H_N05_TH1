import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class UserService {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection("users");

  /// Tạo document user khi đăng ký
  Future<void> createUser(User user, String displayName) async {
    await _users.doc(user.uid).set({
      "uid": user.uid,
      "email": user.email,
      "displayName": displayName,
      "photoUrl": null,   

      "win": 0,
      "lose": 0,
      "draw": 0,

      "elo": 1000,

      "status": "online",

      "createdAt": FieldValue.serverTimestamp(),

      "currentRoomId": null,
    });
  }

Future<void> setCurrentRoom(String uid, String? roomId) async {
  await _users.doc(uid).set(
    {"currentRoomId": roomId},
    SetOptions(merge: true),
  );
}

  Future<void> updateUser(
    String uid, {
    String? displayName,
  }) async {
    final data = <String, dynamic>{};

    if (displayName != null) {
      data["displayName"] = displayName.trim();
    }

    await _users.doc(uid).update(data);
  }

  /// Cập nhật trạng thái
  Future<void> setStatus(String uid, String status) async {
    await _users.doc(uid).update({"status": status});
  }

  /// Cộng số trận thắng
  Future<void> addWin(String uid) async {
    await _users.doc(uid).update({"win": FieldValue.increment(1), "status": "online"});
  }

  /// Cộng số trận thua
  Future<void> addLose(String uid) async {
    await _users.doc(uid).update({"lose": FieldValue.increment(1), "status": "online"});
  }
  
  Future<void> addDraw(String uid) async {
    await _users.doc(uid).update({"draw": FieldValue.increment(1), "status": "online"});
  }

  Future<int> calculateEloAfterMatch(String winnerId, String loserId) async {
    final winnerSnap = await _users.doc(winnerId).get();
    final loserSnap = await _users.doc(loserId).get();

    final winnerElo = (winnerSnap.data()?["elo"] ?? 1000) as int;
    final loserElo = (loserSnap.data()?["elo"] ?? 1000) as int;

    const int k = 32;

    final expectedWinner = 1 / (1 + pow(10, (loserElo - winnerElo) / 400));
    final delta = (k * (1 - expectedWinner)).round();

    await _users.doc(winnerId).update({"elo": FieldValue.increment(delta)});
    await _users.doc(loserId).update({"elo": FieldValue.increment(-delta)});

    return delta;
  }

  /// Lấy thông tin một user
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _users.doc(uid).get();
  }

  /// Lắng nghe realtime thông tin user
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenUser(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<void> updateAvatarUrl(
    String uid,
    String? url,
  ) async {
    await _users.doc(uid).update({
      "photoUrl": url,
    });
  }

  /// Danh sách user online
  Stream<QuerySnapshot<Map<String, dynamic>>> getOnlineUsers() {
    return _users.where("status", isEqualTo: "online").snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> searchUsers(
    String keyword,
  ) async {
    if (keyword.trim().isEmpty) {
      return FirebaseFirestore.instance.collection("users").limit(20).get();
    }

    return FirebaseFirestore.instance
        .collection("users")
        .orderBy("displayName")
        .startAt([keyword])
        .endAt(["$keyword\uf8ff"])
        .get();
  }
}
