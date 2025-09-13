import 'package:swan_sync/swan-sync/presentation/widgets/sync_init_failure_widget.dart';
import 'package:swan_sync/swan-sync/presentation/widgets/sync_init_loading_widget.dart';
import 'package:swan_sync/swan-sync/presentation/screens/sync_demo_screen_refactored.dart';
import 'package:swan_sync/swan-sync/communications/core/app_dependencies_refactored.dart';
import 'package:swan_sync/firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';

class SWANSyncAppInitializer extends StatefulWidget {
  const SWANSyncAppInitializer({super.key});

  @override
  State<SWANSyncAppInitializer> createState() => _SWANSyncAppInitializerState();
}

class _SWANSyncAppInitializerState extends State<SWANSyncAppInitializer> {
  static bool hasInit = false;
  Future<void> _initializeApp() async {
    if (!hasInit)
      hasInit = true;
    else
      return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    await AppDependencies().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done)
          return const SyncDemoScreenRefactored();
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (snapshot.hasError)
                  SyncInitFailureWidget(snapshot: snapshot, retry: () => setState(() {}))
                else
                  const SyncInitLoadingWidget(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    AppDependencies().dispose();
    super.dispose();
  }
}
