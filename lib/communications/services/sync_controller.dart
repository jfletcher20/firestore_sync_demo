import 'package:swan_sync/data/models/data_message_response.dart';
import 'package:swan_sync/communications/services/local_database_service.dart';
import 'package:swan_sync/communications/services/api_service.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';

import 'dart:developer' as developer;
import 'dart:async';

class SyncController {
  static final SyncController _instance = SyncController._internal();
  factory SyncController() => _instance;
  SyncController._internal();

  final LocalDatabaseService localDatabase = LocalDatabaseService();
  final ApiService _apiService = ApiService();

  StreamSubscription<RemoteMessage>? _fcmSubscription;

  bool _isInitialized = false;

  /// Store registered prototypes for dynamic model creation
  final Map<String, ISyncable> _prototypes = {};

  static String? deviceToken = "anonymous swan v2";
  Timer? autoTriggerSyncTimer;

  /// Initialize the sync controller and set up FCM listeners
  Future<void> initialize({bool performAutoSync = true}) async {
    if (_isInitialized) return;

    developer.log('Initializing SyncController', name: 'SyncController');

    await localDatabase.initialize();
    localDatabase.monitorFallbackQueue();

    // TODO: requestpermission? shouldn't have to since we're dealing with data messages
    if (defaultTargetPlatform == TargetPlatform.iOS)
      deviceToken = await FirebaseMessaging.instance.getAPNSToken();
    else
      deviceToken = await FirebaseMessaging.instance.getToken();

    developer.log('FCM Device Token: $deviceToken', name: 'SyncController');

    FirebaseMessaging.onMessage.listen(_handleFcmMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);

    _isInitialized = true;
    developer.log('SyncController initialized', name: 'SyncController');

    if (performAutoSync) autoSyncOnLaunch();

    resetFullSyncTimer();
  }

  void triggerFullSync(Timer timer) {
    developer.log('Auto-triggering full sync of all tables', name: 'SyncController');
    fullSyncAllTables(storeFallback: false);
  }

  void resetFullSyncTimer() {
    autoTriggerSyncTimer?.cancel();
    autoTriggerSyncTimer = Timer.periodic(const Duration(seconds: 45), triggerFullSync);
  }

  Future<void> autoSyncOnLaunch() async {
    try {
      developer.log('Starting auto-sync on launch', name: 'SyncController');
      await fullSyncAllTables();
      developer.log('Auto-sync on launch completed successfully', name: 'SyncController');
    } catch (e) {
      developer.log('Error during auto-sync on launch: $e', name: 'SyncController');
    }
  }

  /// Register a syncable type with both local storage and API service
  void registerSyncableType(ISyncable prototype) {
    _prototypes[prototype.tableName] = prototype;
    localDatabase.registerSyncableType(prototype);
    _apiService.registerSyncableType(prototype);
    developer.log('Registered syncable type: ${prototype.tableName}', name: 'SyncController');
  }

  /// Get prototype for a given table name
  ISyncable? _getPrototypeByTableName(String tableName) => _prototypes[tableName];

  /// Handle FCM messages
  Future<void> _handleFcmMessage(RemoteMessage message) async {
    try {
      print('[SyncController] [FCM] Received FCM message: ${message.data}');

      if (message.data.isEmpty) {
        developer.log('FCM message has no data payload', name: 'SyncController');
        return;
      } else {
        // resetFullSyncTimer();
        // normally would reset countdown for fullsync here until later, but there may be times
        // where multiple notifications didn't arrive or server failed to send notifications,
        // so it's best to force an occasional fullsync anyway
      }

      final dataMessage = DataMessageResponse.fromFcmPayload(message.data);

      if (dataMessage.isDelete) {
        await _handleDeleteFromFcm(dataMessage);
      } else {
        await _handleUpdateFromFcm(dataMessage);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error handling FCM message: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'SyncController',
      );
    }
  }

  /// Handle delete operations from FCM
  Future<void> _handleDeleteFromFcm(DataMessageResponse dataMessage) async {
    try {
      developer.log(
        'Handling delete from FCM: ${dataMessage.uuid} in ${dataMessage.tableName}',
        name: 'SyncController',
      );

      await localDatabase.deleteItem(dataMessage.tableName, dataMessage.uuid);

      developer.log(
        'Successfully deleted item from FCM: ${dataMessage.uuid}',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log('Error handling delete from FCM: $e', name: 'SyncController');
    }
  }

  /// Handle update operations from FCM
  Future<void> _handleUpdateFromFcm(DataMessageResponse dataMessage) async {
    try {
      developer.log(
        'Handling update from FCM: ${dataMessage.uuid} in ${dataMessage.tableName}',
        name: 'SyncController',
      );

      final prototype = _getPrototypeByTableName(dataMessage.tableName);
      if (prototype == null) {
        developer.log(
          'No prototype found for table: ${dataMessage.tableName}',
          name: 'SyncController',
        );
        return;
      }

      if (dataMessage.effectiveId == null) {
        developer.log(
          'No effective ID in FCM message for ${dataMessage.tableName}:${dataMessage.uuid}',
          name: 'SyncController',
        );
        return;
      }

      final serverData = await _apiService.getById(prototype, dataMessage.effectiveId!);
      final result = await localDatabase.handleIncomingData(serverData);

      switch (result) {
        case SyncConflictResult.stored:
        case SyncConflictResult.timestampUpdated:
          developer.log(
            'Successfully handled FCM update: ${dataMessage.uuid}',
            name: 'SyncController',
          );
          break;
        case SyncConflictResult.needsServerUpdate:
          developer.log(
            'Local data is newer, sending to server: ${dataMessage.uuid}',
            name: 'SyncController',
          );
          await _syncLocalItemToServer(dataMessage.tableName, dataMessage.uuid);
          break;
        case SyncConflictResult.error:
          developer.log('Error handling FCM update: ${dataMessage.uuid}', name: 'SyncController');
          break;
        case SyncConflictResult.noChanges:
          developer.log(
            'No changes needed for FCM update: ${dataMessage.uuid}',
            name: 'SyncController',
          );
          break;
      }
    } catch (e) {
      developer.log('Error handling update from FCM: $e', name: 'SyncController');
    }
  }

  /// Sync a local item to the server
  Future<void> _syncLocalItemToServer(String tableName, String uuid) async {
    try {
      final localItem = await localDatabase.getItem(tableName, uuid);
      if (localItem == null) {
        developer.log('Local item not found for server sync: $uuid', name: 'SyncController');
        return;
      }

      ISyncable? result;

      if (localItem.needsSync) {
        // upload new
        result = await _apiService.create(localItem);
        developer.log('Created new item on server: ${localItem.uuid}', name: 'SyncController');
      } else {
        // upload update
        result = await _apiService.update(localItem, localItem.oid);
        developer.log('Updated existing item on server: ${localItem.uuid}', name: 'SyncController');
      }

      // update local (adds oid, in the future might add other data)
      await localDatabase.storeItem(result);
    } catch (e) {
      developer.log('Error syncing local item to server: $e', name: 'SyncController');
    }
  }

  /// Create a new item locally and sync to server
  Future<ISyncable> createItem(ISyncable item) async {
    try {
      developer.log('Creating new item: ${item.uuid} in ${item.tableName}', name: 'SyncController');

      await localDatabase.storeItem(item);

      try {
        final serverResult = await _apiService.create(item);
        await localDatabase.storeItem(serverResult);
        return serverResult;
      } catch (e) {
        developer.log('Failed to sync new item to server immediately: $e', name: 'SyncController');
      }

      return item;
    } catch (e) {
      developer.log('Error creating item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Update an existing item locally and sync to server
  Future<ISyncable?> updateItem(ISyncable item) async {
    try {
      developer.log('Updating item: ${item.uuid} in ${item.tableName}', name: 'SyncController');

      await localDatabase.storeItem(item);

      try {
        ISyncable? serverResult;

        if (item.needsSync) {
          serverResult = await _apiService.create(item);
        } else {
          serverResult = await _apiService.update(item, item.oid);
        }

        await localDatabase.storeItem(serverResult);
        return serverResult;
      } catch (e) {
        developer.log(
          'Failed to sync updated item to server immediately: $e',
          name: 'SyncController',
        );
      }

      return item;
    } catch (e) {
      developer.log('Error updating item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Delete an item locally and sync to server
  Future<void> deleteItem(String tableName, String uuid) async {
    try {
      developer.log('Deleting item: $uuid from $tableName', name: 'SyncController');

      final localItem = await localDatabase.getItem(tableName, uuid);
      if (localItem == null) {
        developer.log('Item not found for deletion: $uuid', name: 'SyncController');
        return;
      }

      if (!localItem.needsSync) {
        try {
          final prototype = _getPrototypeByTableName(tableName);
          if (prototype != null) {
            _apiService.delete(localItem, localItem.oid).then((_) {
              developer.log(
                'Successfully deleted item on server: ${localItem.oid}',
                name: 'SyncController',
              );
              localDatabase.deleteItem(tableName, uuid);
            });
            final deletedItem = localItem.copyWith(
              isDeleted: true,
              updatedAt: DateTime.now().toUtc(),
            );
            await localDatabase.storeItem(deletedItem);
          }
        } catch (e) {
          developer.log(
            'Failed to delete on server: $e - marking as deleted locally',
            name: 'SyncController',
          );
          // mark as deleted otherwise when syncing it will download it again
          final deletedItem = localItem.copyWith(
            isDeleted: true,
            updatedAt: DateTime.now().toUtc(),
          );
          await localDatabase.storeItem(deletedItem);
        }
      } else {
        await localDatabase.deleteItem(tableName, uuid);
        developer.log('Deleted unsynced item locally: $uuid', name: 'SyncController');
      }
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Get all items from a specific table
  Future<List<ISyncable>> getItems(String tableName) async {
    return await localDatabase.getAllItems(tableName);
  }

  /// Get a specific item by UUID
  Future<ISyncable?> getItem(String tableName, String uuid) async {
    return await localDatabase.getItem(tableName, uuid);
  }

  /// Watch changes to a specific table
  Stream<List<ISyncable>> watchTable(String tableName) {
    return localDatabase.watchTable(tableName);
  }

  /// Sync all pending items for a specific table
  Future<void> syncPendingItems(String tableName) async {
    try {
      developer.log('Syncing pending items for table: $tableName', name: 'SyncController');

      final pendingItems = await localDatabase.getItemsNeedingSync(tableName);

      for (final item in pendingItems) {
        await _syncLocalItemToServer(tableName, item.uuid);
      }

      developer.log(
        'Synced ${pendingItems.length} pending items for $tableName',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log('Error syncing pending items: $e', name: 'SyncController');
    }
  }

  /// Perform full sync for a specific table (getAll + conflict resolution)
  Future<void> fullSyncTable(String tableName, {bool storeFallback = true}) async {
    try {
      developer.log('Performing full sync for table: $tableName', name: 'SyncController');

      await syncPendingItems(tableName);

      final prototype = _getPrototypeByTableName(tableName);
      if (prototype == null) {
        developer.log('No prototype found for table: $tableName', name: 'SyncController');
        return;
      }

      final serverItems = await _apiService.getAll(prototype, storeFallback: storeFallback);

      if (serverItems.isNotEmpty) {
        final result = await localDatabase.handleGetAllSync(tableName, serverItems);
        developer.log('GetAll sync result for $tableName: $result', name: 'SyncController');
      }

      developer.log('Full sync completed for table: $tableName', name: 'SyncController');
    } catch (e) {
      developer.log('Error during full sync for $tableName: $e', name: 'SyncController');
    }
  }

  /// Perform full sync for all registered tables
  Future<void> fullSyncAllTables({bool storeFallback = true}) async {
    try {
      developer.log('Performing full sync for all tables', name: 'SyncController');

      final tableNames = localDatabase.getRegisteredTableNames();

      for (final tableName in tableNames) {
        await fullSyncTable(tableName, storeFallback: storeFallback);
      }

      developer.log(
        'Full sync completed for all ${tableNames.length} tables',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log('Error during full sync of all tables: $e', name: 'SyncController');
    }
  }

  /// Check if server is reachable
  Future<bool> isServerReachable() async => await _apiService.isServerReachable();

  /// Clear all data for a specific table
  Future<void> clearTable(String tableName) async => await localDatabase.clearTable(tableName);

  /// Get list of all registered table names
  List<String> getRegisteredTableNames() => localDatabase.getRegisteredTableNames();

  /// Dispose resources
  void dispose() => _fcmSubscription?.cancel();
}
