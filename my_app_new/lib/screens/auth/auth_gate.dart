import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/screens/gameplay/game_screen.dart';

import '../home/home_screen.dart';
import '../room/waiting_room_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return _LoggedInGate(uid: snapshot.data!.uid);
        }

        return const LoginScreen();
      },
    );
  }
}

/// Chỉ check TRẠNG THÁI 1 LẦN lúc app khởi động/reload.
/// Sau đó mọi điều hướng giữa Home / WaitingRoom / Game
/// đều do các màn hình tự Navigator.push/pushReplacement.
class _LoggedInGate extends StatefulWidget {
  final String uid;
  const _LoggedInGate({required this.uid});

  @override
  State<_LoggedInGate> createState() => _LoggedInGateState();
}

class _LoggedInGateState extends State<_LoggedInGate> {
  late Future<Widget> _initialScreenFuture;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _resolveInitialScreen();
  }

  Future<Widget> _resolveInitialScreen() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();

    final currentRoomId = userDoc.data()?['currentRoomId'] as String?;

    if (currentRoomId == null) {
      return const HomeScreen();
    }

    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(currentRoomId)
        .get();

    final roomData = roomDoc.data();
    final status = roomData?['status'];

    if (roomData == null || status == 'finished') {
      // Phòng không còn hiệu lực -> dọn rác rồi về Home
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'currentRoomId': null});
      return const HomeScreen();
    }

    switch (status) {
      case 'playing':
        return GameScreen(roomId: currentRoomId);
      default: // 'waiting' hoặc 'starting'
        return WaitingRoomScreen(roomId: currentRoomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Lỗi tải dữ liệu: ${snapshot.error}")),
          );
        }

        return snapshot.data ?? const HomeScreen();
      },
    );
  }
}