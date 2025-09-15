import 'package:swan_sync/data/models/todo_model.dart';
import 'package:swan_sync/presentation/widgets/sync_init_failure_widget.dart';
import 'package:swan_sync/presentation/widgets/sync_init_loading_widget.dart';
import 'package:swan_sync/presentation/screens/todo_sync_demo_screen.dart';
import 'package:swan_sync/communications/core/app_dependencies.dart';
import 'package:swan_sync/firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  static bool hasInit = false;
  Future<void> _initializeApp() async {
    if (!hasInit)
      hasInit = true;
    else
      return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    // <auth here>

    await AppDependencies().initialize(
      adapters: [TodoModelAdapter()],
      prototypes: [TodoModel.prototype()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) return const TodoSyncDemoScreen();
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
