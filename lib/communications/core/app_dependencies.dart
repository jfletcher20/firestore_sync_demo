import 'package:swan_sync/communications/services/sync_controller.dart';
import 'package:swan_sync/communications/managers/fallback_manager.dart';
import 'package:swan_sync/data/models/todo_model.dart';

import 'package:hive_flutter/hive_flutter.dart';

class AppDependencies {
  static final AppDependencies _instance = AppDependencies._internal();
  factory AppDependencies() => _instance;
  AppDependencies._internal();

  late final SyncController syncController;

  Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoModelAdapter());

    syncController = SyncController();

    syncController.registerSyncableType(TodoModel.prototype());
    FallbackManager.init();

    await syncController.initialize(performAutoSync: true);
  }

  void dispose() {
    syncController.dispose();
  }
}
