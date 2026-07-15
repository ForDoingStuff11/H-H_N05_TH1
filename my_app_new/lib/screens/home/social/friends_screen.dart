import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/screens/home/social/friend_request_tile.dart';
import 'package:my_app/screens/home/social/friend_tile.dart';
import 'package:my_app/services/friend_service.dart';

class FriendsScreen extends StatelessWidget {
  FriendsScreen({super.key});

  final FriendService _friendService = FriendService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends"),
      ),
      body: Column(
        children: [
          StreamBuilder(
            stream: _friendService.getIncomingRequests(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox();
              }

              final requests = snapshot.data!.docs;

              return ExpansionTile(
                leading: Badge(
                  isLabelVisible: requests.isNotEmpty,
                  label: Text("${requests.length}"),
                  child: const Icon(Icons.person_add),
                ),
                title: const Text("Friend Requests"),
                children: requests.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("No pending requests"),
                        ),
                      ]
                    : requests
                        .map(
                          (doc) => FriendRequestTile(
                            request: doc,
                          ),
                        )
                        .toList(),
              );
            },
          ),

          const Divider(height: 0),

          Expanded(
            child: StreamBuilder(
              stream: _friendService.getFriends(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(snapshot.error.toString()),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final friends = snapshot.data!.docs;

                if (friends.isEmpty) {
                  return const Center(
                    child: Text("No friends yet"),
                  );
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    return FriendTile(
                      friendUid: friends[index].id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}