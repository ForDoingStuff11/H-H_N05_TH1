import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/friend_service.dart';
import 'package:my_app/services/invite_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/widgets/user_avatar.dart';

class FriendTile extends StatelessWidget {
  FriendTile({super.key, required this.friendUid});

  final String friendUid;

  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();
  final InviteService _inviteService = InviteService();

  Color _statusColor(String status) {
    switch (status) {
      case "online":
        return Colors.green;
      case "playing":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "playing":
        return Icons.sports_esports;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _userService.getUser(friendUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text("Loading..."));
        }

        final user = snapshot.data!.data()!;
        final status = user["status"] ?? "offline";
        final bool isPlaying = status == "playing";
        final bool isOffline = status == "offline";

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                UserAvatar(photoUrl: user['photoUrl'], radius: 20),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            size: 12,
                            color: _statusColor(status),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              user["displayName"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text("⭐ ${user["elo"]}"),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                FilledButton(
                  onPressed: (isPlaying || isOffline)
                      ? null
                      : () async {
                          final me = await _userService.getUser(
                            FirebaseAuth.instance.currentUser!.uid,
                          );

                          await _inviteService.sendInvite(
                            fromUid: FirebaseAuth.instance.currentUser!.uid,
                            fromName: me.data()!["displayName"],
                            toUid: friendUid,
                            toName: user["displayName"],
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Invitation sent.")),
                            );
                          AudioService.play(SoundEffect.click);
                          }
                        },
                  child: Text(
                    isOffline
                        ? "Offline"
                        : isPlaying
                        ? "In Game"
                        : "Invite",
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case "remove":
                        await _friendService.removeFriend(
                          uid: FirebaseAuth.instance.currentUser!.uid,
                          friendUid: friendUid,
                        );
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: "remove",
                      child: Text("Remove Friend"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
