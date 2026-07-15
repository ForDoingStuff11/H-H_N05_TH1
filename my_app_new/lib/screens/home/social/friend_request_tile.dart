import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/friend_service.dart';
import 'package:my_app/services/user_service.dart';

class FriendRequestTile extends StatelessWidget {
  FriendRequestTile({super.key, required this.request});

  final QueryDocumentSnapshot<Map<String, dynamic>> request;

  final FriendService _friendService = FriendService();
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    final data = request.data();

    final fromUid = data["fromUid"];

    return FutureBuilder(
      future: _userService.getUser(fromUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text("Loading..."));
        }

        final user = snapshot.data!.data()!;

        return ListTile(
          leading: CircleAvatar(child: Text(user["displayName"][0])),
          title: Text(user["displayName"]),
          subtitle: Text("⭐ ${user["elo"]}"),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () async {
                  await _friendService.acceptRequest(
                    requestId: request.id,
                    fromUid: fromUid,
                    toUid: FirebaseAuth.instance.currentUser!.uid,
                  );
                   AudioService.play(SoundEffect.accept);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () async {
                  await _friendService.rejectRequest(request.id);
                  AudioService.play(SoundEffect.click);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
