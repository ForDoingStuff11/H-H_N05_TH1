import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/screens/home/setting/edit_profile_screen.dart';
import 'package:my_app/screens/home/setting/setting_screen.dart';
import 'package:my_app/screens/home/social/friends_screen.dart';
import 'package:my_app/screens/home/social/player_search_screen.dart';
import 'package:my_app/screens/room/match_making_screen.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/widgets/user_avatar.dart';
import '../room/join_room_screen.dart';
import '../room/waiting_room_screen.dart';

import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/user_service.dart';
import '../../services/invite_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RoomService _roomService = RoomService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final InviteService _inviteService = InviteService();
  StreamSubscription? _inviteSubscription;
  StreamSubscription? _sentInviteSub;
  final Set<String> _handledInviteIds = {};

  bool _showingInvite = false;

  void _listenInvite() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _inviteSubscription = _inviteService.incomingInvites(uid).listen((
      snapshot,
    ) {
      if (!mounted) return;
      if (_showingInvite) return;
      if (snapshot.docs.isEmpty) return;

      // ✅ Lọc ra doc chưa handled
      final unhandled = snapshot.docs
          .where((doc) => !_handledInviteIds.contains(doc.id))
          .toList();

      if (unhandled.isEmpty) return;

      _handledInviteIds.add(unhandled.first.id); // ✅ Mark trước khi show
      _showingInvite = true;
      _showInviteDialog(unhandled.first);
    });
  }

  // Lắng nghe cho người GỬI invite: khi bên kia Accept, tự động điều
  // hướng người gửi sang WaitingRoomScreen của phòng vừa được tạo.
  void _listenSentInviteAccepted() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _sentInviteSub = _inviteService.sentInviteAccepted(uid).listen((
      snapshot,
    ) async {
      if (!mounted) return;

      for (final doc in snapshot.docs) {
        if (_handledInviteIds.contains(doc.id)) continue;

        final data = doc.data();
        final roomId = data["roomId"] as String?;
        if (roomId == null) continue;

        _handledInviteIds.add(doc.id);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WaitingRoomScreen(roomId: roomId)),
        );

        // Dọn invite để nó không còn nằm mãi trong stream "accepted"
        await _inviteService.markInviteHandled(doc.id);

        break; // chỉ điều hướng theo 1 invite dù có nhiều cái được accept
      }
    });
  }

  @override
  void initState() {
    super.initState();
    AudioService.playBgm(BackgroundMusic.menu);
    _listenInvite();
    _listenSentInviteAccepted();
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel();
    _sentInviteSub?.cancel();
    super.dispose();
  }

  Future<void> _showInviteDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> invite,
  ) async {
    final data = invite.data();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // ✅ dùng dialogContext riêng
        return AlertDialog(
          title: const Text("Game Invitation"),
          content: Text("${data["fromName"]} invited you to play."),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await _inviteService.rejectInvite(invite.id);
                } catch (e) {
                  debugPrint("🔥 Reject invite ERROR: $e");
                } finally {
                  if (mounted) Navigator.pop(dialogContext);
                  AudioService.play(SoundEffect.click);
                }
              },
              child: const Text("Reject"),
            ),
            FilledButton(
              onPressed: () async {
                debugPrint("1️⃣ Accept pressed");
                try {
                  final roomId = await _roomService.createRoom(
                    hostId: currentUid,
                    guestId: data["fromUid"] as String,
                  );
                  debugPrint("2️⃣ Room created: $roomId");

                  await _inviteService.acceptInvite(
                    inviteId: invite.id,
                    roomId: roomId,
                  );
                  debugPrint("3️⃣ Invite accepted");

                  if (!mounted) {
                    debugPrint("❌ Widget unmounted, stopping here");
                    return;
                  }

                  Navigator.pop(dialogContext);
                  debugPrint("4️⃣ Dialog popped");

                  AudioService.play(SoundEffect.accept);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaitingRoomScreen(roomId: roomId),
                    ),
                  );
                  debugPrint("5️⃣ Pushed to WaitingRoomScreen");
                } catch (e, st) {
                  debugPrint("🔥 ERROR: $e");
                  debugPrint("🔥 Stack: $st");
                  if (mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text("Accept"),
            ),
          ],
        );
      },
    );

    _showingInvite = false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Online Caro"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            onPressed: () async {
              await _userService.setStatus(uid, "offline");
              await _authService.signOut();
              AudioService.play(SoundEffect.click);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _userService.listenUser(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!.data()!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                //---------------------------------------
                // PROFILE
                //---------------------------------------
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            UserAvatar(photoUrl: user['photoUrl'], radius: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user["displayName"],
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(user["email"]),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Status: ${user["status"]}",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                );
                                AudioService.play(SoundEffect.click);
                              },
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text("ELO"),
                                Text("${user["elo"]}"),
                              ],
                            ),
                            Column(
                              children: [
                                const Text("Win"),
                                Text("${user["win"]}"),
                              ],
                            ),
                            Column(
                              children: [
                                const Text("Lose"),
                                Text("${user["lose"]}"),
                              ],
                            ),
                            Column(
                              children: [
                                const Text("Draw"),
                                Text("${user["draw"]}"),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                //---------------------------------------
                // PLAY
                //---------------------------------------
                const Text(
                  "Play",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MatchmakingScreen(),
                      ),
                    );
                    AudioService.play(SoundEffect.click);
                  },
                  icon: const Icon(Icons.flash_on),
                  label: const Text("Ranked Match"),
                ),

                ElevatedButton.icon(
                  onPressed: () async {
                    final roomId = await _roomService.createRoom(hostId: uid);

                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WaitingRoomScreen(roomId: roomId),
                      ),
                    );
                    AudioService.play(SoundEffect.click);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Create Room"),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                    );
                    AudioService.play(SoundEffect.click);
                  },
                  icon: const Icon(Icons.meeting_room),
                  label: const Text("Join Room"),
                ),

                const SizedBox(height: 24),

                //---------------------------------------
                // SOCIAL
                //---------------------------------------
                const Text(
                  "Social",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlayerSearchScreen(),
                      ),
                    );
                    AudioService.play(SoundEffect.click);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text("Search Player"),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FriendsScreen()),
                    );
                    AudioService.play(SoundEffect.click);
                  },
                  icon: const Icon(Icons.people),
                  label: const Text("Friends"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
