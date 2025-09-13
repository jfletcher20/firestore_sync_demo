import 'package:swan_sync/a-SWAN-sync-example/presentation/screens/SWAN_sync_app_initializer.dart';

import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SyncDemoApp());
}

class SyncDemoApp extends StatelessWidget {
  const SyncDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swan Sync Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SWANSyncAppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}
