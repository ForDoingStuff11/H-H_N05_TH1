import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import 'package:my_app/services/cloudinary_service.dart';
import 'package:my_app/services/room_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/widgets/user_avatar.dart';

import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final UserService _userService;
  late final CloudinaryService _cloudinaryService;

  Uint8List? _selectedImage;
  String? _photoUrl;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cloudinaryService = CloudinaryService();
    _userService = UserService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    setState(() {
      _selectedImage = bytes;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Display name cannot be empty")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      String? uploadedUrl = _photoUrl;

      if (_selectedImage != null) {
        uploadedUrl = await _cloudinaryService.upload(_selectedImage!);
      }

      await _userService.updateUser(
        FirebaseAuth.instance.currentUser!.uid,
        displayName: name,
      );

      if (uploadedUrl != _photoUrl) {
        await _userService.updateAvatarUrl(
          FirebaseAuth.instance.currentUser!.uid,
          uploadedUrl,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi khi lưu: $e")));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildStatChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    final email = data["email"] ?? "—";
    final elo = data["elo"] ?? 1000;
    final win = data["win"] ?? 0;
    final lose = data["lose"] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(Icons.emoji_events, "ELO", "$elo", Colors.orange),
              const SizedBox(width: 10),
              _buildStatChip(Icons.check_circle, "Thắng", "$win", Colors.green),
              const SizedBox(width: 10),
              _buildStatChip(Icons.cancel, "Thua", "$lose", Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistory(String uid) {
    final roomService = RoomService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Lịch sử đấu",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: roomService.getHistory(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const Text(
                "Không tải được lịch sử đấu",
                style: TextStyle(color: Colors.grey),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Chưa có trận đấu nào",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final room = docs[index].data();

                final hostId = room['hostId'];
                final guestId = room['guestId'];
                final winnerId = room['winnerId'];
                final isRanked = room['isRanked'] ?? false;
                final boardSize = room['boardSize'] ?? 15;

                final eloChangesRaw = room['eloChanges'];
                final Map<String, dynamic>? eloChanges = eloChangesRaw != null
                    ? Map<String, dynamic>.from(eloChangesRaw)
                    : null;
                final int? myEloChange = eloChanges != null
                    ? (eloChanges[uid] as num?)?.toInt()
                    : null;

                final startedAtRaw = room['startedAt'];
                final finishedAtRaw = room['finishedAt'];

                String durationStr = '';
                if (startedAtRaw is Timestamp && finishedAtRaw is Timestamp) {
                  final duration = finishedAtRaw.toDate().difference(
                    startedAtRaw.toDate(),
                  );
                  final minutes = duration.inMinutes;
                  final seconds = duration.inSeconds % 60;
                  durationStr = minutes > 0
                      ? "$minutes phút $seconds giây"
                      : "$seconds giây";
                }

                final opponentId = uid == hostId ? guestId : hostId;

                final isWin = winnerId == uid;
                final isDraw = winnerId == null;
                final resultColor = isDraw
                    ? Colors.grey
                    : (isWin ? Colors.green : Colors.redAccent);
                final resultLabel = isDraw ? "Hòa" : (isWin ? "Thắng" : "Thua");

                final timestamp = room['finishedAt'];
                String dateStr = '';
                if (timestamp is Timestamp) {
                  dateStr = DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(timestamp.toDate());
                }

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: opponentId == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(opponentId)
                            .get(),
                  builder: (context, oppSnapshot) {
                    final oppData = oppSnapshot.data?.data();
                    final opponentName = oppData?['displayName'] ?? 'Đối thủ';
                    final opponentPhoto = oppData?['photoUrl'];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(photoUrl: opponentPhoto, radius: 55),
                          const SizedBox(width: 10),
                          Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: resultColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "vs $opponentName",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isRanked) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.military_tech,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  "$boardSize x $boardSize"
                                  "${dateStr.isNotEmpty ? " • $dateStr" : ""}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (durationStr.isNotEmpty)
                                  Text(
                                    "⏱ $durationStr",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: resultColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              resultLabel,
                              style: TextStyle(
                                color: resultColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (isRanked && myEloChange != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              myEloChange >= 0
                                  ? "+$myEloChange"
                                  : "$myEloChange",
                              style: TextStyle(
                                color: myEloChange >= 0
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
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
      body: StreamBuilder(
        stream: _userService.listenUser(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();

          if (data == null) {
            return const Center(child: Text("User not found"));
          }

          if (!_loaded) {
            _loaded = true;

            _photoUrl = data["photoUrl"];

            _nameController.text = data["displayName"] ?? "";
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundImage: MemoryImage(_selectedImage!),
                            ),
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 15,
                                child: Icon(Icons.camera_alt, size: 16),
                              ),
                            ),
                          ],
                        )
                      : UserAvatar(
                          photoUrl: _photoUrl,
                          radius: 55,
                          badge: const CircleAvatar(
                            radius: 15,
                            child: Icon(Icons.camera_alt, size: 16),
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // ----- Thông tin cơ bản: email / elo / thắng-thua -----
                _buildInfoSection(data),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Display Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Enter display name",
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            AudioService.play(SoundEffect.click);
                            _save();
                          },
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? "Saving..." : "Save Changes"),
                  ),
                ),

                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),

                // ----- Lịch sử đấu -----
                _buildMatchHistory(uid),
              ],
            ),
          );
        },
      ),
    );
  }
}
