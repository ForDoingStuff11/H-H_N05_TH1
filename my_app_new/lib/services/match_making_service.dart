import 'package:cloud_firestore/cloud_firestore.dart';

class MatchmakingService {
  final _firestore = FirebaseFirestore.instance;
  final _queue = FirebaseFirestore.instance.collection("matchmaking_queue");

  // Vào hàng đợi
  Future<void> joinQueue({required String uid, required int elo}) async {
    await _queue.doc(uid).set({
      "uid": uid,
      "elo": elo,
      "status": "waiting",
      "roomId": null,
      "joinedAt": FieldValue.serverTimestamp(),
    });
  }

  // Rời hàng đợi (hủy tìm trận)
  Future<void> leaveQueue(String uid) async {
    await _queue.doc(uid).delete();
  }

  // Lắng nghe trạng thái của chính mình trong hàng đợi
  // (status chuyển "waiting" -> "matched" kèm roomId khi ghép xong)
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenMyQueueStatus(
    String uid,
  ) {
    return _queue.doc(uid).snapshots();
  }

  // Thử tìm 1 đối thủ elo gần nhất đang chờ và ghép trận.
  // Gọi định kỳ (vd mỗi 2-3s) từ client trong lúc đang chờ.
  // maxEloDiff: biên độ elo chấp nhận được, tăng dần theo thời gian chờ
  // để tránh chờ quá lâu (do MatchmakingScreen truyền vào).
  Future<void> tryMatch({
    required String uid,
    required int elo,
    required int maxEloDiff,
  }) async {
    final candidates = await _queue
        .where("status", isEqualTo: "waiting")
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? best;
    int bestDiff = 1 << 30;

    for (final doc in candidates.docs) {
      if (doc.id == uid) continue;

      final data = doc.data();
      final candidateElo = data["elo"] as int? ?? 0;
      final diff = (candidateElo - elo).abs();

      if (diff <= maxEloDiff && diff < bestDiff) {
        bestDiff = diff;
        best = doc;
      }
    }

    if (best == null) return; // chưa có ai phù hợp, chờ vòng poll sau

    final opponentUid = best.id;

    // Quy ước: uid nhỏ hơn (so sánh chuỗi) sẽ làm host, để tránh trường hợp
    // cả 2 client cùng chạy tryMatch và cùng tạo 2 phòng khác nhau cho
    // cùng một cặp đấu.
    final bool selfIsHost = uid.compareTo(opponentUid) < 0;
    final String hostUid = selfIsHost ? uid : opponentUid;
    final String guestUid = selfIsHost ? opponentUid : uid;

    final myRef = _queue.doc(uid);
    final opponentRef = _queue.doc(opponentUid);
    final roomRef = _firestore.collection("rooms").doc();

    const int boardSize = 15;

    try {
      await _firestore.runTransaction((transaction) async {
        final mySnap = await transaction.get(myRef);
        final opponentSnap = await transaction.get(opponentRef);

        final myData = mySnap.data();
        final opponentData = opponentSnap.data();

        // 1 trong 2 đã bị match bởi client khác / đã rời hàng đợi -> bỏ qua
        if (myData == null || opponentData == null) return;
        if (myData["status"] != "waiting") return;
        if (opponentData["status"] != "waiting") return;

        transaction.set(roomRef, {
          "hostId": hostUid,
          "guestId": guestUid,
          "players": [hostUid, guestUid],
          "boardSize": boardSize,
          "timeLimit": 30,
          "isRanked": true,
          "status": "waiting",
          "hostReady": false,
          "guestReady": false,
          "board": List.filled(boardSize * boardSize, ""),
          "currentTurn": "X",
          "winnerId": null,
          "createdAt": FieldValue.serverTimestamp(),
        });

        transaction.update(myRef, {
          "status": "matched",
          "crurrentRoomId": roomRef.id,
        });
        transaction.update(opponentRef, {
          "status": "matched",
          "crurrentRoomId": roomRef.id,
        });
      });
    } catch (_) {
      // Transaction thất bại (vd bị client khác match trước) -> im lặng,
      // vòng poll kế tiếp sẽ thử lại với ứng viên khác.
    }
  }
}