import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

class PresenceObserver extends StatefulWidget {
  final Widget child;

  const PresenceObserver({super.key, required this.child});

  @override
  State<PresenceObserver> createState() => _PresenceObserverState();
}

class _PresenceObserverState extends State<PresenceObserver>
    with WidgetsBindingObserver {
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App quay lại foreground, đang thực sự hiển thị trên màn hình
        _setOnline();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App bị minimize / chuyển app khác / bị OS thu hồi
        _setOffline();
        break;

      case AppLifecycleState.inactive:
        // Trạng thái chuyển tiếp rất ngắn (vd kéo control center, có cuộc
        // gọi đến...) - cố tình KHÔNG set offline ở đây để tránh
        // online/offline nhấp nháy liên tục cho những gián đoạn nhỏ.
        break;
    }
  }

  void _setOnline() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userService.setStatus(uid, "online");
  }

  void _setOffline() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userService.setStatus(uid, "offline");
  }

  @override
  Widget build(BuildContext context) => widget.child;
}