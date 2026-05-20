import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonate_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:resonate_app/ui/auth_gate.dart';
// Aliased import to prevent duplicate name errors
//import 'package:resonate_app/controllers/socket_controller.dart' as base_ctrl;
import 'package:resonate_app/providers/session_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep socket listener active in background
    ref.watch(socketServiceProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Resonate',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
