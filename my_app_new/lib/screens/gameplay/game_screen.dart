import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/user_service.dart';

import '../../services/room_service.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final RoomService _roomService = RoomService();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _dialogShown = false;
  bool _leavingRoom = false;
  bool _drawDialogShown = false;

  // ---- Turn timer state ----
  Timer? _turnTimer;
  Timestamp?
  _timeoutCalledForTurnStart; // tránh gọi handleTimeout nhiều lần cho cùng 1 lượt

  // ---- Rematch timeout state ----
  Timer? _rematchTimer;

  List<String>? _prevBoard;
  Timestamp? _warningPlayedForTurnStart;

  @override
  void initState() {
    super.initState();
    AudioService.playBgm(BackgroundMusic.game);
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _rematchTimer?.cancel();
    super.dispose();
  }

  void _startRematchTimeout(BuildContext dialogContext) {
    _rematchTimer?.cancel();

    _rematchTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      try {
        await _roomService.cancelRematch(
          roomId: widget.roomId,
          uid: currentUserId,
        );
      } catch (e) {
        debugPrint("🔥 cancelRematch ERROR: $e");
      }
      if (!mounted) return;
      if (Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }
      AudioService.playBgm(BackgroundMusic.menu);
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _ensureUiTicker() {
    _turnTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  int _computeRemainingSeconds(Timestamp? turnStartedAt, int timeLimit) {
    if (timeLimit == -1 || turnStartedAt == null) return -1;

    final elapsed = DateTime.now().difference(turnStartedAt.toDate()).inSeconds;
    final remaining = timeLimit - elapsed;

    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _confirmLeaveGame(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Rời trận đấu?"),
          content: const Text(
            "Nếu thoát bây giờ, bạn sẽ bị xử thua. Bạn có chắc chắn muốn rời không?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                AudioService.play(SoundEffect.click);
              },
              child: const Text("Ở lại"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                AudioService.play(SoundEffect.click);
                AudioService.playBgm(BackgroundMusic.menu);
              },
              child: const Text(
                "Rời phòng",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _leavingRoom = true;

    try {
      await _roomService.leaveRoom(roomId: widget.roomId, uid: currentUserId);

      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _leavingRoom = false; // reset để không bị kẹt trạng thái
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Không thể rời phòng: $e")));
      }
    }
  }

  void _showDrawRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Đối thủ muốn cầu hòa"),
          content: const Text(
            "Bạn có đồng ý kết thúc trận đấu với kết quả hòa không?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _roomService.respondDraw(
                  roomId: widget.roomId,
                  uid: currentUserId,
                  accept: false,
                );
                AudioService.play(SoundEffect.click);
              },
              child: const Text("Từ chối"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _roomService.respondDraw(
                  roomId: widget.roomId,
                  uid: currentUserId,
                  accept: true,
                );
                AudioService.play(SoundEffect.click);
              },
              child: const Text("Đồng ý hòa"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRequestDraw(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xét hòa"),
        content: const Text("Gửi yêu cầu xét hòa tới đối thủ?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              AudioService.play(SoundEffect.click);
            },
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              AudioService.play(SoundEffect.click);
            },
            child: const Text("Gửi"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _roomService.requestDraw(roomId: widget.roomId, uid: currentUserId);
  }

  void _showGameOverDialog(BuildContext context, String? winnerId) {
    if (_dialogShown) return;

    _dialogShown = true;

    final myId = FirebaseAuth.instance.currentUser!.uid;

    final isWinner = winnerId == myId;
    final isDraw = winnerId == null;
    if (isWinner) {
      AudioService.play(SoundEffect.win);
    } else if (isDraw) {
      AudioService.play(SoundEffect.draw);
    } else {
      AudioService.play(SoundEffect.lose);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StreamBuilder(
          stream: _roomService.listenRoom(widget.roomId),
          builder: (_, snapshot) {
            if (!snapshot.hasData) {
              return AlertDialog(
                title: Text(
                  isDraw
                      ? "🤝 Draw!"
                      : (isWinner ? "🎉 You Win!" : "😢 You Lose!"),
                ),
                content: const Text("Đang tải..."),
              );
            }

            final room = snapshot.data!.data()!;
            final String? rematchRoomId = room["rematchRoomId"];

            // Đối thủ (hoặc chính mình) đã tạo xong phòng mới -> tự chuyển sang
            if (rematchRoomId != null) {
              _rematchTimer?.cancel();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => GameScreen(roomId: rematchRoomId),
                  ),
                );
              });
              return const SizedBox.shrink();
            }

            final hostId = room["hostId"];
            final bool isHost = myId == hostId;
            final bool myRematch = isHost
                ? (room["hostRematch"] ?? false)
                : (room["guestRematch"] ?? false);
            final bool opponentRematch = isHost
                ? (room["guestRematch"] ?? false)
                : (room["hostRematch"] ?? false);

            String message;
            if (myRematch) {
              message =
                  "Đang chờ đối thủ đồng ý tái đấu... (tối đa 10s, hết giờ sẽ tự thoát)";
            } else if (opponentRematch) {
              message = "Đối thủ muốn tái đấu! Bạn đồng ý không?";
            } else {
              message = isDraw
                  ? "Trận đấu kết thúc với tỷ số hòa!"
                  : (isWinner ? "Bạn đã chiến thắng!" : "Cố gắng lần sau nhé!");
            }

            return AlertDialog(
              title: Text(
                isDraw
                    ? "🤝 Draw!"
                    : (isWinner ? "🎉 You Win!" : "😢 You Lose!"),
              ),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    _rematchTimer?.cancel();
                    Navigator.of(dialogContext).pop();
                    UserService().setCurrentRoom(currentUserId, null);

                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    AudioService.play(SoundEffect.click);
                    AudioService.playBgm(BackgroundMusic.menu);
                  },
                  child: const Text("Thoát"),
                ),
                TextButton(
                  onPressed: myRematch
                      ? null
                      : () {
                          _roomService.requestRematch(
                            roomId: widget.roomId,
                            uid: myId,
                          );
                          _startRematchTimeout(dialogContext);
                          AudioService.play(SoundEffect.click);
                        },
                  child: Text(myRematch ? "Đã gửi..." : "Đấu lại"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onCellTap(
    int index,
    String currentTurn,
    String mySymbol,
    List<String> board,
  ) async {
    if (board[index].isNotEmpty) {
      return;
    }
    if (mySymbol != currentTurn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not your turn!")));
      return;
    }
    await _roomService.makeMove(
      roomId: widget.roomId,
      index: index,
      symbol: currentTurn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeaveGame(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Online Caro"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _confirmLeaveGame(context);
              AudioService.play(SoundEffect.click);
            },
          ),
        ),
        body: StreamBuilder(
          stream: _roomService.listenRoom(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final room = snapshot.data!.data()!;

            final board = List<String>.from(room["board"]);
            final currentTurn = room["currentTurn"];
            final hostId = room["hostId"];
            final guestId = room["guestId"];
            final mySymbol = currentUserId == hostId ? "X" : "O";
            final status = room["status"];
            final winnerId = room["winnerId"];
            final drawBy = room["drawRequestedBy"];
            final drawStatus = room["drawStatus"];
            final int boardSize = room["boardSize"];
            final int timeLimit = room["timeLimit"] ?? -1;

            final Timestamp? turnStartedAt = room["turnStartedAt"];
            final int remainingSeconds = _computeRemainingSeconds(
              turnStartedAt,
              timeLimit,
            );

            // Phát tiếng đánh cờ khi board thay đổi (kể cả nước đi của đối thủ)
            if (_prevBoard != null && _prevBoard!.join() != board.join()) {
              AudioService.play(SoundEffect.place);
            }
            _prevBoard = board;

            if (status == "playing") {
              _ensureUiTicker();

              if (timeLimit != -1 &&
                  remainingSeconds <= 5 &&
                  remainingSeconds > 0 &&
                  mySymbol == currentTurn &&
                  _warningPlayedForTurnStart != turnStartedAt) {
                _warningPlayedForTurnStart = turnStartedAt;
                AudioService.play(SoundEffect.timeoutWarning);
              }

              if (timeLimit != -1 &&
                  remainingSeconds <= 0 &&
                  mySymbol == currentTurn &&
                  _timeoutCalledForTurnStart != turnStartedAt) {
                _timeoutCalledForTurnStart = turnStartedAt;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _roomService.handleTimeout(roomId: widget.roomId);
                });
              }
            } else {
              _turnTimer?.cancel();
              _turnTimer = null;
            }

            if (status == "finished" && !_leavingRoom) {
              Future.microtask(() {
                _showGameOverDialog(context, winnerId);
              });
            }

            if (status == "playing" &&
                drawStatus == "pending" &&
                drawBy != currentUserId) {
              if (!_drawDialogShown) {
                _drawDialogShown = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showDrawRequestDialog(context);
                });
              }
            } else if (drawStatus != "pending") {
              _drawDialogShown = false;
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "Current Turn: $currentTurn (${mySymbol == currentTurn ? "🟢 Your Turn" : "🔴 Opponent's Turn"})",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ---- Turn timer ----
                  Text(
                    timeLimit == -1
                        ? "⏱ No time limit"
                        : "⏱ $remainingSeconds s",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (timeLimit != -1 && remainingSeconds <= 5)
                          ? Colors.red
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface, // ✅ thay vì Colors.black87
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double maxBoardPixel =
                            constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight;

                        final double cellSize = boardSize <= 10
                            ? maxBoardPixel / boardSize
                            : 36;

                        final double boardPixelSize = cellSize * boardSize;
                        final double fontSize = (cellSize * 0.5).clamp(12, 26);

                        final gridView = GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: board.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: boardSize,
                              ),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                _onCellTap(index, currentTurn, mySymbol, board);
                              },
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    board[index],
                                    style: TextStyle(
                                      color: board[index] == "O"
                                          ? Colors.red
                                          : board[index] == "X"
                                          ? Colors.blue
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: fontSize,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );

                        if (boardSize <= 10) {
                          // Board nhỏ: không cần zoom/pan
                          return AspectRatio(aspectRatio: 1, child: gridView);
                        }

                        // Board lớn: cho phép pinch-zoom + kéo để xem/bấm dễ hơn
                        return InteractiveViewer(
                          constrained: false,
                          minScale: 0.5,
                          maxScale: 4,
                          boundaryMargin: const EdgeInsets.all(80),
                          child: SizedBox(
                            width: boardPixelSize,
                            height: boardPixelSize,
                            child: gridView,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: (status == "playing" && drawStatus != "pending")
                        ? () {
                            _confirmRequestDraw(context);
                            AudioService.play(SoundEffect.click);
                          }
                        : (status == "playing" &&
                              drawStatus == "pending" &&
                              drawBy == currentUserId)
                        ? null // đang chờ phản hồi, disable nút
                        : null,
                    icon: const Icon(Icons.handshake),
                    label: Text(
                      (drawStatus == "pending" && drawBy == currentUserId)
                          ? "Đang chờ đối thủ..."
                          : "Cầu hòa",
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text("Host: $hostId"),

                  Text("Guest: $guestId"),

                  Text("Room ID: ${widget.roomId}"),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
