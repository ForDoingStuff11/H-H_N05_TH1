import 'package:flutter/material.dart';
import 'package:my_app/models/sound.dart';
import 'package:my_app/services/audio_service.dart';
import '../../services/room_service.dart';
import 'waiting_room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final RoomService _roomService = RoomService();
  final TextEditingController _roomIdController = TextEditingController();

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();

    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Room ID"),
        ),
      );
      return;
    }

    try {
      await _roomService.joinRoom(roomId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            roomId: roomId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Room"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Join a Room",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                labelText: "Room ID",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:() {_joinRoom(); AudioService.play(SoundEffect.click);},
                child: const Text("JOIN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}