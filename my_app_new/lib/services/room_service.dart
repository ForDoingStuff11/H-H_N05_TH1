import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/services/user_service.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Tạo phòng mới
  Future<String> createRoom({
    required String hostId,
    String? guestId,
    int boardSize = 15,
    int timeLimit = 30,
    bool isRanked = false,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final docRef = await _firestore.collection('rooms').add({
      'hostId': hostId,

      "players": [hostId, guestId],

      'isRanked': isRanked,

      'hostReady': false,

      'guestReady': false,

      'guestId': guestId,

      'status': 'waiting',

      'currentTurn': 'X',

      "turnStartedAt": null,

      "board": List.generate(boardSize * boardSize, (_) => ""),

      'winnerId': null,

      'drawRequestedBy': null,

      'drawStatus': null,

      'createdAt': FieldValue.serverTimestamp(),

      "startedAt": null,

      "finishedAt": null,

      "boardSize": boardSize,

      "winCondition": 5,

      "timeLimit": timeLimit,
    });
    await _userService.setCurrentRoom(hostId, docRef.id);
    if (guestId != null) {
      await _userService.setCurrentRoom(guestId, docRef.id);
    }
    return docRef.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRoom(String roomId) {
    return FirebaseFirestore.instance
        .collection("rooms")
        .doc(roomId)
        .snapshots();
  }

  Future<void> joinRoom(String roomId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final roomRef = _firestore.collection("rooms").doc(roomId);

    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      throw Exception("Room not found");
    }

    final data = snapshot.data()!;

    if (data["guestId"] != null) {
      throw Exception("Room is full");
    }

    await roomRef.update({
      "guestId": user.uid,
      "players": FieldValue.arrayUnion([user.uid]),
      "guestReady": false,
    });
    await _userService.setCurrentRoom(user.uid, roomId);
  }

  Future<void> leaveRoom({required String roomId, required String uid}) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);

    Map<String, dynamic>? finishedRoomData;
    String? winnerId;
    String? loserId;

    await _firestore.runTransaction((transaction) async {
      final room = await transaction.get(roomRef);
      if (!room.exists) return;

      final data = room.data()!;
      final status = data["status"];

      if (status == "playing") {
        final hostId = data["hostId"];
        final guestId = data["guestId"];
        winnerId = uid == hostId ? guestId : hostId;
        loserId = uid;

        transaction.update(roomRef, {
          "status": "finished",
          "winnerId": winnerId,
          "endReason": "left",
          "finishedAt": FieldValue.serverTimestamp(),
        });

        finishedRoomData = data;
        return;
      }

      if (status == "finished") return;

      final hostId = data["hostId"];
      final guestId = data["guestId"];

      if (uid == hostId) {
        if (guestId != null) {
          transaction.update(roomRef, {
            "hostId": guestId,
            "guestId": null,
            "players": [guestId],
            "hostReady": false,
            "guestReady": false,
            "status": "waiting",
          });
        } else {
          transaction.delete(roomRef);
        }
      } else {
        transaction.update(roomRef, {
          "guestId": null,
          "guestReady": false,
          "status": "waiting",
          "players": FieldValue.arrayRemove([guestId]),
        });
      }
    });

    // ---- Cộng thống kê TRƯỚC khi xoá currentRoomId ----
    if (finishedRoomData != null && winnerId != null && loserId != null) {
      final isRanked = finishedRoomData!["isRanked"] ?? false;
      await _userService.addWin(winnerId!);
      await _userService.addLose(loserId!);
      if (isRanked) {
        final delta = await _userService.calculateEloAfterMatch(
          winnerId!,
          loserId!,
        );
        await roomRef.update({
          "eloChanges": {winnerId!: delta, loserId!: -delta},
        });
      }
    }

    // ---- Xoá currentRoomId SAU CÙNG ----
    await _userService.setCurrentRoom(uid, null);
  }

  Future<void> updateSettings({
    required String roomId,
    required int boardSize,
    required int timeLimit,
    required bool isRanked,
  }) async {
    await _firestore.collection("rooms").doc(roomId).update({
      "boardSize": boardSize,
      "timeLimit": timeLimit,
      "isRanked": isRanked,

      // đổi setting => reset ready
      "hostReady": false,
      "guestReady": false,
    });
  }

  Future<void> toggleReady({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);

      final data = snapshot.data()!;

      final bool isHost = uid == data["hostId"];

      final bool currentReady = isHost ? data["hostReady"] : data["guestReady"];

      // Đảo trạng thái Ready
      transaction.update(roomRef, {
        isHost ? "hostReady" : "guestReady": !currentReady,
      });

      final bool hostReady = isHost ? !currentReady : data["hostReady"];

      final bool guestReady = isHost ? data["guestReady"] : !currentReady;

      // Chỉ khi cả hai đều Ready mới bắt đầu đếm ngược
      if (hostReady && guestReady) {
        transaction.update(roomRef, {"status": "starting"});
      } else {
        // Nếu một người bỏ Ready thì quay lại waiting
        transaction.update(roomRef, {"status": "waiting"});
      }
    });
  }

  Future<void> startGame(String roomId) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null) return;
      final int boardSize = data["boardSize"];
      final List<String> board = List.filled(boardSize * boardSize, "");
      transaction.update(roomRef, {
        "status": "playing",
        "board": board,
        "startedAt": FieldValue.serverTimestamp(),
        "turnStartedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> makeMove({
    required String roomId,
    required int index,
    required String symbol,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);

    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final room = snapshot.data()!;
    final board = List<String>.from(room["board"]);
    final int boardSize = room["boardSize"];

    if (board[index].isNotEmpty) return;

    board[index] = symbol;

    if (_checkWin(
      board,
      index ~/ boardSize,
      index % boardSize,
      symbol,
      boardSize,
    )) {
      String winner = symbol == "X" ? room["hostId"] : room["guestId"];
      String loser = symbol == "O" ? room["hostId"] : room["guestId"];

      // 1. Cập nhật room "finished" TRƯỚC, để thỏa điều kiện rule
      await roomRef.update({
        "winnerId": winner,
        "status": "finished",
        "board": board,
        "currentTurn": symbol == "X" ? "O" : "X",
        "finishedAt": FieldValue.serverTimestamp(),
      });

      // 2. Sau đó mới cộng win/lose/elo
      await _userService.addWin(winner);
      await _userService.addLose(loser);

      if (room["isRanked"] == true) {
        final delta = await _userService.calculateEloAfterMatch(winner, loser);
        await roomRef.update({
          "eloChanges": {winner: delta, loser: -delta},
        });
      }
    } else {
      await roomRef.update({
        "board": board,
        "currentTurn": symbol == "X" ? "O" : "X",
        "turnStartedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  bool _checkDirection(
    List<String> board,
    int row,
    int col,
    int dx,
    int dy,
    String symbol,
    int boardSize,
  ) {
    int stack = 0;

    // bắt đầu từ vị trí -4
    int startRow = row - dx * 4;
    int startCol = col - dy * 4;

    for (int i = 0; i < 9; i++) {
      int r = startRow + dx * i;
      int c = startCol + dy * i;

      // ngoài bàn cờ thì coi như ngắt chuỗi
      if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) {
        continue;
      }

      if (board[r * boardSize + c] == symbol) {
        stack++;

        if (stack >= 5) {
          return true;
        }
      } else {
        stack = 0;
      }
    }

    return false;
  }

  bool _checkWin(
    List<String> board,
    int row,
    int col,
    String symbol,
    int boardSize,
  ) {
    return _checkDirection(board, row, col, 0, 1, symbol, boardSize) || // ngang
        _checkDirection(board, row, col, 1, 0, symbol, boardSize) || // dọc
        _checkDirection(
          board,
          row,
          col,
          1,
          1,
          symbol,
          boardSize,
        ) || // chéo chính
        _checkDirection(board, row, col, 1, -1, symbol, boardSize); // chéo phụ
  }

  Future<void> handleTimeout({required String roomId}) async {
    final docRef = _firestore.collection("rooms").doc(roomId);

    Map<String, dynamic>? finishedRoomData;
    String? winnerId;
    String? loserId;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) return;

      if (data["status"] != "playing") return;

      final hostId = data["hostId"];
      final guestId = data["guestId"];
      final currentTurn = data["currentTurn"];

      winnerId = currentTurn == "X" ? guestId : hostId;
      loserId = currentTurn == "X" ? hostId : guestId;

      transaction.update(docRef, {
        "status": "finished",
        "winnerId": winnerId,
        "endReason": "timeout",
        "finishedAt": FieldValue.serverTimestamp(),
      });

      finishedRoomData = data;
    });

    if (finishedRoomData != null && winnerId != null && loserId != null) {
      final isRanked = finishedRoomData!["isRanked"] ?? false;

      await _userService.addWin(winnerId!);
      await _userService.addLose(loserId!);

      if (isRanked) {
        final delta = await _userService.calculateEloAfterMatch(
          winnerId!,
          loserId!,
        );
        await docRef.update({
          "eloChanges": {winnerId!: delta, loserId!: -delta},
        });
      }
    }
  }

  Future<void> requestRematch({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);
    final newRoomRef = _firestore.collection("rooms").doc(); // sinh sẵn ID mới

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null) return;

      if (data["status"] != "finished") return; // chỉ rematch khi ván đã xong
      if (data["rematchRoomId"] != null)
        return; // đã có người tạo phòng mới rồi

      final hostId = data["hostId"];
      final bool isHost = uid == hostId;

      final bool otherWantsRematch = isHost
          ? (data["guestRematch"] ?? false)
          : (data["hostRematch"] ?? false);

      if (otherWantsRematch) {
        // Cả 2 đồng ý -> tạo phòng mới, copy nguyên setting + host/guest cũ
        final int boardSize = data["boardSize"];
        final int timeLimit = data["timeLimit"];
        final bool isRanked = data["isRanked"] ?? false;
        final guestId = data["guestId"];

        transaction.set(newRoomRef, {
          "hostId": hostId,
          "guestId": guestId,
          "boardSize": boardSize,
          "timeLimit": timeLimit,
          "isRanked": isRanked,
          "status": "playing", // vào thẳng ván mới, khỏi qua phòng chờ lại
          "board": List.filled(boardSize * boardSize, ""),
          "currentTurn": "X",
          "winnerId": null,
          "hostReady": true,
          "guestReady": true,
          "createdAt": FieldValue.serverTimestamp(),
          "startedAt": FieldValue.serverTimestamp(),
          "turnStartedAt": FieldValue.serverTimestamp(),
        });

        transaction.update(_firestore.collection("users").doc(hostId), {
          "currentRoomId": newRoomRef.id,
        });
        transaction.update(_firestore.collection("users").doc(guestId), {
          "currentRoomId": newRoomRef.id,
        });
        // Đánh dấu phòng cũ để cả 2 client biết đường chuyển sang phòng mới
        transaction.update(roomRef, {"rematchRoomId": newRoomRef.id});
      } else {
        // Mới có 1 người đồng ý -> đánh dấu chờ đối thủ
        transaction.update(roomRef, {
          (isHost ? "hostRematch" : "guestRematch"): true,
        });
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getHistory(String uid) {
    return FirebaseFirestore.instance
        .collection("rooms")
        .where("players", arrayContains: uid)
        .where("status", isEqualTo: "finished")
        .orderBy("finishedAt", descending: true)
        .snapshots();
  }

  Future<void> cancelRematch({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);
    final snapshot = await roomRef.get();
    final data = snapshot.data();
    if (data == null) return;

    if (data["status"] != "finished") return;
    if (data["rematchRoomId"] != null) return; // đã tạo phòng mới rồi, khỏi hủy

    final bool isHost =
        uid == data["hostId"]; // đổi hostUid nếu Firestore bạn dùng tên đó
    await roomRef.update({(isHost ? "hostRematch" : "guestRematch"): false});
  }

  Future<void> requestDraw({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null) return;

      if (data["status"] != "playing") return;
      if (data["drawStatus"] == "pending") return; // đã có yêu cầu đang chờ

      transaction.update(roomRef, {
        "drawRequestedBy": uid,
        "drawStatus": "pending",
      });
    });
  }

  Future<void> respondDraw({
    required String roomId,
    required String uid,
    required bool accept,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);

    Map<String, dynamic>? finishedRoomData;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      final data = snapshot.data();
      if (data == null) return;

      if (data["drawStatus"] != "pending") return;
      if (data["drawRequestedBy"] == uid) return;

      if (accept) {
        transaction.update(roomRef, {
          "status": "finished",
          "winnerId": null,
          "endReason": "draw",
          "drawStatus": "accepted",
          "finishedAt": FieldValue.serverTimestamp(),
        });
        finishedRoomData = data;
      } else {
        transaction.update(roomRef, {
          "drawStatus": null,
          "drawRequestedBy": null,
        });
      }
    });

    if (finishedRoomData != null) {
      final hostId = finishedRoomData!["hostId"];
      final guestId = finishedRoomData!["guestId"];

      await _userService.addDraw(hostId);
      await _userService.addDraw(guestId);
    }
  }

  Future<void> cancelDrawRequest({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _firestore.collection("rooms").doc(roomId);
    final snapshot = await roomRef.get();
    final data = snapshot.data();
    if (data == null) return;

    if (data["drawStatus"] != "pending") return;
    if (data["drawRequestedBy"] != uid) return;

    await roomRef.update({"drawStatus": null, "drawRequestedBy": null});
  }
}
