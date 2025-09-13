import 'package:swan_sync/swan-sync/data/i_syncable.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'dart:developer' as developer;
import 'dart:async';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  /// List of registered ISyncable types for dynamic model creation
  final List<ISyncable> _registeredTypes = [];

  /// Initialize Hive and register adapters
  Future<void> initialize() async {
    developer.log('Initializing LocalDatabaseService', name: 'LocalDatabaseService');

    await Hive.initFlutter();

    developer.log('LocalDatabaseService initialized', name: 'LocalDatabaseService');
  }

  /// Register a syncable type for dynamic model creation
  void registerSyncableType(ISyncable prototype) {
    _registeredTypes.removeWhere((type) => type.tableName == prototype.tableName);
    _registeredTypes.add(prototype);
    developer.log('Registered syncable type: ${prototype.tableName}', name: 'LocalDatabaseService');
  }

  /// Find the correct ISyncable prototype by table name
  ISyncable? _findPrototypeByTableName(String tableName) {
    try {
      return _registeredTypes.firstWhere((type) => type.tableName == tableName);
    } catch (e) {
      return null;
    }
  }

  /// Get or create a box for a specific table
  Future<Box<Map<dynamic, dynamic>>> _getBox(String tableName) async {
    if (!Hive.isBoxOpen(tableName)) {
      return await Hive.openBox<Map<dynamic, dynamic>>(tableName);
    }
    return Hive.box<Map<dynamic, dynamic>>(tableName);
  }

  /// Store or update an item in the local database
  Future<void> storeItem(ISyncable item) async {
    try {
      developer.log(
        'Storing item: ${item.uuid} in table: ${item.tableName}',
        name: 'LocalDatabaseService',
      );

      final box = await _getBox(item.tableName);
      await box.put(item.uuid, item.toHiveData());

      developer.log('Successfully stored item: ${item.uuid}', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error storing item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Get an item by UUID from a specific table
  Future<ISyncable?> getItem(String tableName, String uuid) async {
    try {
      final box = await _getBox(tableName);
      final data = box.get(uuid);

      if (data == null) return null;

      final prototype = _findPrototypeByTableName(tableName);
      if (prototype == null) {
        developer.log('No prototype found for table: $tableName', name: 'LocalDatabaseService');
        return null;
      }

      // Cast to Map<String, dynamic> to handle Hive's dynamic types
      final hiveData = Map<String, dynamic>.from(data);
      return prototype.fromHiveData(hiveData);
    } catch (e) {
      developer.log('Error getting item: $e', name: 'LocalDatabaseService');
      return null;
    }
  }

  /// Get all items from a specific table
  Future<List<ISyncable>> getAllItems(String tableName) async {
    try {
      final box = await _getBox(tableName);
      final prototype = _findPrototypeByTableName(tableName);

      if (prototype == null) {
        developer.log('No prototype found for table: $tableName', name: 'LocalDatabaseService');
        return [];
      }

      final List<ISyncable> items = [];
      for (final data in box.values) {
        try {
          // Cast to Map<String, dynamic> to handle Hive's dynamic types
          final hiveData = Map<String, dynamic>.from(data);
          final item = prototype.fromHiveData(hiveData);
          items.add(item);
        } catch (e) {
          developer.log('Error parsing item from Hive data: $e', name: 'LocalDatabaseService');
        }
      }

      return items;
    } catch (e) {
      developer.log('Error getting all items: $e', name: 'LocalDatabaseService');
      return [];
    }
  }

  /// Get items that need to be synced to the server (oid == -1)
  Future<List<ISyncable>> getItemsNeedingSync(String tableName) async {
    try {
      final allItems = await getAllItems(tableName);
      return allItems.where((item) => item.needsSync).toList();
    } catch (e) {
      developer.log('Error getting items needing sync: $e', name: 'LocalDatabaseService');
      return [];
    }
  }

  /// Delete an item (hard delete)
  Future<void> deleteItem(String tableName, String uuid) async {
    try {
      developer.log('Deleting item: $uuid from table: $tableName', name: 'LocalDatabaseService');

      final box = await _getBox(tableName);
      await box.delete(uuid);

      developer.log('Successfully deleted item: $uuid', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Handle conflict resolution for getAll sync
  /// Removes local items that don't exist on server (were deleted remotely)
  Future<SyncConflictResult> handleGetAllSync(String tableName, List<ISyncable> serverItems) async {
    try {
      developer.log(
        'Handling getAll sync for table: $tableName with ${serverItems.length} server items',
        name: 'LocalDatabaseService',
      );

      final localItems = await getAllItems(tableName);
      final serverUuids = serverItems.map((item) => item.uuid).toSet();

      int deletedCount = 0;
      int updatedCount = 0;
      int addedCount = 0;

      // Check for local items that were deleted on server
      for (final localItem in localItems) {
        // Only check items that have been synced to server (oid != -1)
        if (localItem.oid != -1 && !serverUuids.contains(localItem.uuid)) {
          await deleteItem(tableName, localItem.uuid);
          deletedCount++;
          developer.log(
            'Deleted local item ${localItem.uuid} - not found on server',
            name: 'LocalDatabaseService',
          );
        }
      }

      // Store/update server items
      final localItemsByUuid = {for (var item in localItems) item.uuid: item};

      for (final serverItem in serverItems) {
        final localItem = localItemsByUuid[serverItem.uuid];

        if (localItem == null) {
          // New item from server
          await storeItem(serverItem);
          addedCount++;
        } else {
          // Existing item - check for conflicts
          final result = await _resolveConflict(localItem, serverItem);
          if (result == SyncConflictResult.stored ||
              result == SyncConflictResult.timestampUpdated) {
            updatedCount++;
          }
        }
      }

      developer.log(
        'GetAll sync completed: $addedCount added, $updatedCount updated, $deletedCount deleted',
        name: 'LocalDatabaseService',
      );

      if (deletedCount > 0 || updatedCount > 0 || addedCount > 0) {
        return SyncConflictResult.stored;
      } else {
        return SyncConflictResult.noChanges;
      }
    } catch (e) {
      developer.log('Error handling getAll sync: $e', name: 'LocalDatabaseService');
      return SyncConflictResult.error;
    }
  }

  /// Handle incoming data from FCM or API with conflict resolution
  Future<SyncConflictResult> handleIncomingData(ISyncable incomingData) async {
    try {
      developer.log('Handling incoming data: ${incomingData.uuid}', name: 'LocalDatabaseService');

      final existingItem = await getItem(incomingData.tableName, incomingData.uuid);

      if (existingItem == null) {
        // No local copy exists, store the incoming data
        await storeItem(incomingData);

        developer.log('Stored new item: ${incomingData.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.stored;
      }

      // Item exists locally, resolve conflict
      return await _resolveConflict(existingItem, incomingData);
    } catch (e) {
      developer.log('Error handling incoming data: $e', name: 'LocalDatabaseService');
      return SyncConflictResult.error;
    }
  }

  /// Resolve conflicts between local and incoming data
  Future<SyncConflictResult> _resolveConflict(ISyncable localItem, ISyncable incomingData) async {
    developer.log('Resolving conflict for: ${localItem.uuid}', name: 'LocalDatabaseService');

    // Compare timestamps
    if (localItem.isNewerThan(incomingData)) {
      // Local is newer
      if (localItem.hasSameContentAs(incomingData)) {
        // Same data, just update timestamps to match server
        final updatedItem = localItem.copyWith(
          oid: incomingData.oid,
          updatedAt: incomingData.updatedAt,
        );
        await storeItem(updatedItem);
        developer.log('Updated timestamps for: ${localItem.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.timestampUpdated;
      } else {
        // Different data, local is newer - need to send to server
        developer.log(
          'Local data is newer, needs server update: ${localItem.uuid}',
          name: 'LocalDatabaseService',
        );
        return SyncConflictResult.needsServerUpdate;
      }
    } else if (incomingData.isNewerThan(localItem)) {
      // Incoming data is newer or same timestamp
      if (localItem.hasSameContentAs(incomingData)) {
        // Same data, just update timestamps and oid
        final updatedItem = localItem.copyWith(
          oid: incomingData.oid,
          updatedAt: incomingData.updatedAt,
        );
        await storeItem(updatedItem);
        developer.log('Updated timestamps for: ${localItem.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.timestampUpdated;
      } else {
        // Different data, incoming is newer - store incoming data
        await storeItem(incomingData);
        developer.log(
          'Stored newer incoming data for: ${localItem.uuid}',
          name: 'LocalDatabaseService',
        );
        return SyncConflictResult.stored;
      }
    } else {
      // do nothing, timestamps are identical
      developer.log('No changes needed for: ${localItem.uuid}', name: 'LocalDatabaseService');
      return SyncConflictResult.noChanges;
    }
  }

  /// Create a new item locally (will need to be synced)
  Future<ISyncable> createItem(ISyncable prototype, Map<String, dynamic> data) async {
    try {
      // Use the prototype's fromHiveData or a factory method to create the item
      // For now, we'll need a different approach - this will depend on the specific model
      throw UnimplementedError('Use model-specific factory methods to create items');
    } catch (e) {
      developer.log('Error creating item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Update an existing item locally (will need to be synced)
  Future<ISyncable?> updateItem(String tableName, String uuid, ISyncable updatedItem) async {
    try {
      await storeItem(updatedItem);
      developer.log('Updated local item: $uuid', name: 'LocalDatabaseService');
      return updatedItem;
    } catch (e) {
      developer.log('Error updating item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Mark an item as synced (update oid from server)
  Future<void> markItemAsSynced(String tableName, String uuid, int serverOid) async {
    try {
      final item = await getItem(tableName, uuid);

      if (item != null) {
        final syncedItem = item.copyWith(oid: serverOid);
        await storeItem(syncedItem);
        developer.log(
          'Marked item as synced: $uuid with oid: $serverOid',
          name: 'LocalDatabaseService',
        );
      }
    } catch (e) {
      developer.log('Error marking item as synced: $e', name: 'LocalDatabaseService');
    }
  }

  /// Get stream of changes for a specific table
  Stream<List<ISyncable>> watchTable(String tableName) {
    return Stream.fromFuture(
      _getBox(tableName),
    ).asyncExpand((box) => box.watch().asyncMap((_) => getAllItems(tableName)));
  }

  /// Clear all data for a specific table
  Future<void> clearTable(String tableName) async {
    try {
      final box = await _getBox(tableName);
      await box.clear();
      developer.log('Cleared table: $tableName', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error clearing table: $e', name: 'LocalDatabaseService');
    }
  }

  /// Get all registered table names
  List<String> getRegisteredTableNames() {
    return _registeredTypes.map((type) => type.tableName).toList();
  }

  /// Close all boxes and cleanup
  Future<void> dispose() async {
    await Hive.close();
  }
}

/// Result of sync conflict resolution
enum SyncConflictResult {
  stored, // Incoming data was stored
  needsServerUpdate, // Local data is newer, needs to be sent to server
  timestampUpdated, // Only timestamps were updated
  noChanges, // No changes were made
  error, // An error occurred
}
