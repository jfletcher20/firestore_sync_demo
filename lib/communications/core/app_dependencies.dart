import 'package:swan_sync/communications/services/sync_controller.dart';
import 'package:swan_sync/communications/static/fallback.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'package:hive_flutter/hive_flutter.dart';

class AppDependencies {
  // singleton design pattern
  static final AppDependencies _instance = AppDependencies._internal();
  factory AppDependencies() => _instance;
  AppDependencies._internal();
  // to create table operations, client code accesses the syncController
  late final SyncController syncController;

  Future<void> initialize({
    required List<TypeAdapter> adapters,
    required List<ISyncable> prototypes,
  }) async {
    for (var adapter in adapters)
      if (!Hive.isAdapterRegistered(adapter.typeId)) Hive.registerAdapter(adapter);

    syncController = SyncController();

    for (var syncable in prototypes) syncController.registerSyncableType(syncable);
    Fallback.init();

    await syncController.initialize(performAutoSync: true);
  }

  void dispose() {
    syncController.dispose();
  }
}
