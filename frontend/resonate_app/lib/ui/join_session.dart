import 'package:flutter/material.dart';
import 'package:resonate_app/services/socket_service.dart';

class JoinSession extends StatefulWidget {
  const JoinSession({super.key});

  @override
  State<JoinSession> createState() => _JoinSessionState();
}

class _JoinSessionState extends State<JoinSession> {
  final TextEditingController ctrl = TextEditingController();
  final socketService = SocketService();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void joinRoom() {
    if (ctrl.text.trim().isEmpty) return;

    socketService.emit("join-room", {"code": ctrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Session"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 80, color: Colors.blue),

            const SizedBox(height: 20),

            const Text(
              "Enter Session Code",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "Ask your friend for the session code to join the music room.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 20,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "ABC123",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: joinRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Join Session",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
