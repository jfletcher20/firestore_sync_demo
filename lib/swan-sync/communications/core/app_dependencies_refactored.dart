import 'package:swan_sync/swan-sync/communications/services/sync_controller_refactored.dart';
import 'package:swan_sync/swan-sync/communications/services/fallback_service.dart';
import 'package:swan_sync/swan-sync/data/models/todo_model.dart';

import 'package:hive_flutter/hive_flutter.dart';

class AppDependencies {
  static final AppDependencies _instance = AppDependencies._internal();
  factory AppDependencies() => _instance;
  AppDependencies._internal();

  late final SyncController syncController;

  Future<void> initialize() async {
    // Register Hive adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TodoModelAdapter());
    }

    syncController = SyncController();

    // Register the TodoModel as a syncable type
    syncController.registerSyncableType(TodoModel.prototype());
    FallbackQueueManager.init();

    // Initialize the sync controller with auto-sync enabled
    await syncController.initialize(performAutoSync: true);
  }

  void dispose() {
    syncController.dispose();
  }
}
