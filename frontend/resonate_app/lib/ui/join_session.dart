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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resonate'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            TextField(controller: ctrl),
            TextButton(
              onPressed: () {
                socketService.emit("join-room", {"code": ctrl.text});
              },
              child: Text('Submit Code'),
            ),
          ],
        ),
      ),
    );
  }
}
