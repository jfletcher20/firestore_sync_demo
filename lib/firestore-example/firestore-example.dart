import 'package:swan_sync/firestore-example/presentation/screens/app_initializer.dart';
import 'package:swan_sync/firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';

void firestoreExmaple() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firestore demo',
      theme: ThemeData.light(
        useMaterial3: true,
      ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }

  static String deviceName = "anonymous";
}
