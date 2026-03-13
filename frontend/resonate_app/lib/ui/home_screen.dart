import 'package:flutter/material.dart';
import 'package:resonate_app/ui/join_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resonate')),
      body: Center(
        child: Column(
          children: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => JoinSession()),
                );
              },
              child: Text('Join a Session'),
            ),

            TextButton(onPressed: () {}, child: Text('Create a session')),
          ],
        ),
      ),
    );
  }
}
