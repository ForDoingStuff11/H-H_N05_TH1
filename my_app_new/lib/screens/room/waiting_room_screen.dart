import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'dart:async';
import 'package:my_app/screens/gameplay/game_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/user_service.dart';
import '../../services/room_service.dart';
import 'package:flutter/services.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomId;

  const WaitingRoomScreen({super.key, required this.roomId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final RoomService _roomService = RoomService();
  final UserService _userService = UserService();

  bool _starting = false;
  int _countdown = 3;
  Timer? _timer;
  late final String uid;

  final List<int> _boardSizeOptions = const [10, 15, 20, 25, 30, 35, 40];
  final List<int> _timeLimitOptions = const [10, 15, 20, 30, 45, 60, -1];

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (_starting) return;
    _starting = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_countdown == 1) {
        timer.cancel();
        await _roomService.startGame(widget.roomId);
      } else {
        setState(() {
          _countdown--;
        });
      }
    });

    setState(() {});
  }

  Future<void> _updateSettings({
    required int boardSize,
    required int timeLimit,
    required bool isRanked,
  }) async {
    await _roomService.updateSettings(
      roomId: widget.roomId,
      boardSize: boardSize,
      timeLimit: timeLimit,
      isRanked: isRanked,
    );
  }

  Future<void> _toggleReady(bool currentReady) async {
    await _roomService.toggleReady(roomId: widget.roomId, uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Room Lobby"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            AudioService.play(SoundEffect.click);
            AudioService.playBgm(BackgroundMusic.menu);
            await _roomService.leaveRoom(roomId: widget.roomId, uid: uid);

            if (!mounted) return;

            Navigator.pop(context);
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

          final roomStatus = room["status"];
          final bool isHost = room["hostId"] == uid;
          final bool isWaiting = roomStatus == "waiting";
          final bool hostReady = room["hostReady"] ?? false;
          final bool guestReady = room["guestReady"] ?? false;
          final bool myReady = isHost ? hostReady : guestReady;
          final int currentBoardSize = room["boardSize"];
          final int currentTimeLimit = room["timeLimit"];
          final bool currentIsRanked = room["isRanked"] ?? false;
          final String? guestId = room["guestId"];

          if (roomStatus == "playing") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(roomId: widget.roomId),
                ),
              );
            });
          }
          if (roomStatus == "starting") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startCountdown();
            });
          }

          return SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Waiting Room",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "RoomID: ${widget.roomId.substring(0, 8)}...",
                          style: const TextStyle(fontSize: 22),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            AudioService.play(SoundEffect.click);
                            await Clipboard.setData(
                              ClipboardData(text: widget.roomId),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Copied!")),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // ---- Room settings ----
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text("Board Size"),
                              trailing: isHost && isWaiting && !currentIsRanked
                                  ? DropdownButton<int>(
                                      value: currentBoardSize,
                                      items: _boardSizeOptions
                                          .map(
                                            (size) => DropdownMenuItem(
                                              value: size,
                                              child: Text("$size x $size"),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateSettings(
                                            boardSize: value,
                                            timeLimit: currentTimeLimit,
                                            isRanked: false,
                                          );
                                        }
                                      },
                                    )
                                  : Text(
                                      "$currentBoardSize x $currentBoardSize",
                                    ),
                            ),
                            ListTile(
                              title: const Text("Turn Time"),
                              trailing: isHost && isWaiting && !currentIsRanked
                                  ? DropdownButton<int>(
                                      value: currentTimeLimit,
                                      items: _timeLimitOptions
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text("$t s"),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateSettings(
                                            boardSize: currentBoardSize,
                                            timeLimit: value,
                                            isRanked: false,
                                          );
                                        }
                                      },
                                    )
                                  : Text("$currentTimeLimit s"),
                            ),
                            if (isHost && isWaiting)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  currentIsRanked
                                      ? "Trận đấu hạng"
                                      : "Chỉ host mới chỉnh được thiết lập phòng",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    if (!_starting) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _PlayerTile(
                                uid: room["hostId"],
                                label: "Host",
                                ready: hostReady,
                                isRanked: currentIsRanked,
                                userService: _userService,
                              ),
                              const Divider(),
                              guestId == null
                                  ? const ListTile(
                                      leading: Icon(Icons.person_outline),
                                      title: Text("Waiting for player..."),
                                    )
                                  : _PlayerTile(
                                      uid: guestId,
                                      label: "Guest",
                                      ready: guestReady,
                                      isRanked: currentIsRanked,
                                      userService: _userService,
                                    ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (isWaiting && guestId != null)
                        ElevatedButton.icon(
                          onPressed: () {
                            _toggleReady(myReady);
                            AudioService.play(
                              myReady ? SoundEffect.click : SoundEffect.accept,
                            );
                          },
                          icon: Icon(
                            myReady ? Icons.cancel : Icons.check_circle,
                          ),
                          label: Text(myReady ? "Cancel Ready" : "Ready"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: myReady
                                ? Colors.grey
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                        )
                      else if (isWaiting)
                        const CircularProgressIndicator(),
                    ] else ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Opponent Found!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Starting in $_countdown...",
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hiển thị avatar + displayName (+ elo nếu ranked) cho 1 người chơi
/// trong phòng, thay vì hiện UID thô.
class _PlayerTile extends StatelessWidget {
  final String uid;
  final String label;
  final bool ready;
  final bool isRanked;
  final UserService userService;

  const _PlayerTile({
    required this.uid,
    required this.label,
    required this.ready,
    required this.isRanked,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: userService.listenUser(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final String displayName =
            (data?["displayName"] as String?)?.trim().isNotEmpty == true
            ? data!["displayName"]
            : "Người chơi";
        final String? photoUrl = data?["photoUrl"] as String?;
        final int? elo = data?["elo"] as int?;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(displayName),
          subtitle: isRanked && elo != null
              ? Text("$label · ELO: $elo")
              : Text(label),
          trailing: Icon(
            ready ? Icons.check_circle : Icons.hourglass_empty,
            color: ready ? Colors.green : Colors.orange,
          ),
        );
      },
    );
  }
}