import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/match_making_service.dart';

import '../../services/user_service.dart';
import '../room/waiting_room_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final MatchmakingService _matchmakingService = MatchmakingService();
  final UserService _userService = UserService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  StreamSubscription? _queueSub;
  Timer? _pollTimer;
  Timer? _tickTimer;

  int _elo = 1000;
  int _secondsWaiting = 0;
  bool _joined = false;
  bool _navigated = false; // tránh push WaitingRoomScreen 2 lần

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Lấy elo hiện tại của người chơi để làm mốc ghép trận
    final userSnap = await _userService.listenUser(uid).first;
    final userData = userSnap.data();
    _elo = (userData?["elo"] as int?) ?? 1000;

    if (!mounted) return;

    await _matchmakingService.joinQueue(uid: uid, elo: _elo);
    _joined = true;

    // Lắng nghe khi nào mình được ghép trận
    _queueSub = _matchmakingService.listenMyQueueStatus(uid).listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      if (data["status"] == "matched" && !_navigated) {
        final roomId = data["roomId"] as String?;
        if (roomId == null) return;

        _navigated = true;
        _stopPolling();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => WaitingRoomScreen(roomId: roomId)),
        );
      }
    });

    // Cứ mỗi 2s thử tìm đối thủ 1 lần, nới biên độ elo dần theo thời gian
    // chờ để tránh chờ quá lâu.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _matchmakingService.tryMatch(
        uid: uid,
        elo: _elo,
        maxEloDiff: _currentEloRange(),
      );
    });

    // Đếm giây hiển thị cho người chơi biết đã chờ bao lâu
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsWaiting++);
    });
  }

  // Biên độ ELO chấp nhận được, nới rộng dần theo thời gian chờ:
  // 0-15s: ±100, 15-30s: ±200, 30-60s: ±400, sau 60s: không giới hạn
  int _currentEloRange() {
    if (_secondsWaiting < 15) return 100;
    if (_secondsWaiting < 30) return 200;
    if (_secondsWaiting < 60) return 400;
    return 1 << 30;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
  }

  Future<void> _cancelSearch() async {
    _stopPolling();
    _queueSub?.cancel();

    if (_joined) {
      await _matchmakingService.leaveQueue(uid);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopPolling();
    _queueSub?.cancel();

    // Nếu người chơi thoát màn hình bằng cách khác (vd back button hệ thống)
    // mà chưa kịp rời hàng đợi thì vẫn cố dọn dẹp.
    if (_joined && !_navigated) {
      _matchmakingService.leaveQueue(uid);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ranked Match"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              AudioService.play(SoundEffect.click);
              AudioService.playBgm(BackgroundMusic.menu);
              _cancelSearch();
            },
          ),
        ),

        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                "Đang tìm đối thủ...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text("ELO của bạn: $_elo"),
              const SizedBox(height: 8),
              Text("Đã chờ: ${_secondsWaiting}s"),
              const SizedBox(height: 8),
              Text(
                "Biên độ ELO đang tìm: ±${_currentEloRange() >= (1 << 30) ? "∞" : _currentEloRange()}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  _cancelSearch();
                  AudioService.play(SoundEffect.click);
                },
                child: const Text("Hủy tìm trận"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
