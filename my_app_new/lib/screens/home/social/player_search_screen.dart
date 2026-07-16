import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/widgets/user_avatar.dart';

import '../../../services/friend_service.dart';
import '../../../services/user_service.dart';

class PlayerSearchScreen extends StatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  State<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends State<PlayerSearchScreen> {
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _players = [];
  Set<String> _friendIds = {};
  Set<String> _pendingIds = {}; // lời mời đã gửi, đang chờ

  bool _loading = false;

  Future<void> _search(String uid) async {
    setState(() {
      _loading = true;
    });

    final result = await _userService.searchUsers(
      _searchController.text.trim(),
    );

    _players = result.docs
        .map((e) => e.data())
        .where((p) => p["uid"] != uid)
        .toList();

    _friendIds = await _friendService.getFriendIds(uid);
    _pendingIds = await _friendService.getSentPendingRequestIds(uid);

    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Player"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            AudioService.play(SoundEffect.click);
            AudioService.playBgm(BackgroundMusic.menu);
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Display Name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    await _search(uid);
                    AudioService.play(SoundEffect.click);
                  },
                ),
              ),
              onSubmitted: (_) => _search(uid),
            ),

            const SizedBox(height: 20),

            if (_loading) const CircularProgressIndicator(),

            if (!_loading)
              Expanded(
                child: ListView.builder(
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    final String playerUid = player["uid"];
                    final isFriend = _friendIds.contains(playerUid);
                    final isPending = _pendingIds.contains(playerUid);

                    return Card(
                      child: ListTile(
                        leading: UserAvatar(
                          photoUrl: player['photoUrl'],
                          radius: 20,
                        ),
                        title: Text(player["displayName"]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player["email"]),
                            Text("⭐ ${player["elo"]}"),
                          ],
                        ),
                        trailing: isFriend
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text("Friend"),
                                ],
                              )
                            : isPending
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 6),
                                  Text("Pending"),
                                ],
                              )
                            : SizedBox(
                                width: 90,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final doc = await _userService.getUser(uid);
                                    final fromName = doc.data()?["displayName"];

                                    await _friendService.sendRequest(
                                      fromUid: uid,
                                      fromName: fromName,
                                      toUid: playerUid,
                                    );

                                    setState(() {
                                      _pendingIds.add(
                                        playerUid,
                                      ); // đổi sang pending, không phải friend
                                    });

                                    AudioService.play(SoundEffect.click);
                                  },
                                  child: const Text("Add"),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
