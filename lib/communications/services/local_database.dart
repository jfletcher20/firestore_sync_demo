import 'package:swan_sync/communications/util/fallback/fallback.dart';
import 'package:swan_sync/communications/core/SWAN_sync.dart';
import 'package:swan_sync/communications/util/communications.dart';
import 'package:swan_sync/communications/core/request_type.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:async';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  /// List of registered ISyncable types for dynamic model creation
  Future<LocalDatabase> initialize([String? subDir]) => Hive.initFlutter(subDir).then((_) => this);

  /// Find the correct ISyncable prototype by table name
  ISyncable? _findPrototypeByTableName(String tableName) {
    return SwanSync.prototypeFor(tableName);
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
        name: 'LocalDatabase',
      );

      final box = await _getBox(item.tableName);
      await box.put(item.uuid, item.toHiveData());

      developer.log('Successfully stored item: ${item.uuid}', name: 'LocalDatabase');
    } catch (e) {
      developer.log('Error storing item: $e', name: 'LocalDatabase');
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
        developer.log('No prototype found for table: $tableName', name: 'LocalDatabase');
        return null;
      }

      final hiveData = Map<String, dynamic>.from(data);
      return prototype.fromHiveData(hiveData);
    } catch (e) {
      developer.log('Error getting item: $e', name: 'LocalDatabase');
      return null;
    }
  }

  Future<ISyncable?> getItemById(String tableName, int oid) async {
    try {
      final box = await _getBox(tableName);
      final data = box.values.firstWhere((item) => item['oid'] == oid, orElse: () => {});

      if (data.isEmpty) return null;

      final prototype = _findPrototypeByTableName(tableName);
      if (prototype == null) {
        developer.log('No prototype found for table: $tableName', name: 'LocalDatabase');
        return null;
      }

      final hiveData = Map<String, dynamic>.from(data);
      return prototype.fromHiveData(hiveData);
    } catch (e) {
      developer.log('Error getting item: $e', name: 'LocalDatabase');
      return null;
    }
  }

  /// Get all items from a specific table (excludes deleted items by default)
  Future<List<ISyncable>> getAllItems(String tableName, {bool includeDeleted = false}) async {
    try {
      final box = await _getBox(tableName);
      final prototype = _findPrototypeByTableName(tableName);

      if (prototype == null) {
        developer.log('No prototype found for table: $tableName', name: 'LocalDatabase');
        return [];
      }

      final List<ISyncable> items = [];
      for (final data in box.values) {
        try {
          final hiveData = Map<String, dynamic>.from(data);
          final item = prototype.fromHiveData(hiveData);
          if (!includeDeleted && item.isDeleted) continue;
          items.add(item);
        } catch (e) {
          developer.log('Error parsing item from Hive data: $e', name: 'LocalDatabase');
        }
      }

      return items;
    } catch (e) {
      developer.log('Error getting all items: $e', name: 'LocalDatabase');
      return [];
    }
  }

  /// Get items that need to be synced to the server (oid == -1)
  Future<List<ISyncable>> getItemsNeedingSync(String tableName) async {
    try {
      final allItems = await getAllItems(tableName);
      return allItems.where((item) => item.needsSync).toList();
    } catch (e) {
      developer.log('Error getting items needing sync: $e', name: 'LocalDatabase');
      return [];
    }
  }

  /// Delete an item (hard delete)
  Future<void> deleteItem(String tableName, String uuid) async {
    try {
      developer.log('Deleting item: $uuid from table: $tableName', name: 'LocalDatabase');
      final box = await _getBox(tableName);
      await box.delete(uuid);
      developer.log('Successfully deleted item: $uuid', name: 'LocalDatabase');
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'LocalDatabase');
      rethrow;
    }
  }

  /// Handle conflict resolution for getAll sync
  /// Removes local items that don't exist on server (were deleted remotely)
  /// Sends delete requests for items that were locally deleted while offline
  Future<SyncConflictResult> handleGetAllSync(String tableName, List<ISyncable> serverItems) async {
    try {
      developer.log(
        'Handling getAll sync for table: $tableName with ${serverItems.length} server items',
        name: 'LocalDatabase',
      );

      final localItems = await getAllItems(tableName, includeDeleted: true);
      final serverUuids = serverItems.map((item) => item.uuid).toSet();

      int deletedCount = 0;
      int updatedCount = 0;
      int addedCount = 0;
      int serverDeletedCount = 0;

      for (final localItem in localItems) {
        if (localItem.isDeleted && localItem.oid != -1) {
          try {
            final prototype = _findPrototypeByTableName(tableName);
            if (prototype != null) {
              await Communications.request(
                prototype,
                null,
                localItem.uuid,
                oid: localItem.oid,
                delete: true,
              );
              await deleteItem(tableName, localItem.uuid);
              serverDeletedCount++;
              developer.log(
                'Sent delete request to server for locally deleted item ${localItem.uuid}',
                name: 'LocalDatabase',
              );
            }
          } catch (e) {
            developer.log(
              'Failed to delete item ${localItem.uuid} on server: $e',
              name: 'LocalDatabase',
            );
          }
        }
      }

      for (final localItem in localItems) {
        if (localItem.oid != -1 && !localItem.isDeleted && !serverUuids.contains(localItem.uuid)) {
          await deleteItem(tableName, localItem.uuid);
          deletedCount++;
          developer.log(
            'Deleted local item ${localItem.uuid} - not found on server',
            name: 'LocalDatabase',
          );
        }
      }

      final localItemsByUuid = {for (var item in localItems) item.uuid: item};

      for (final serverItem in serverItems) {
        final localItem = localItemsByUuid[serverItem.uuid];

        if (localItem == null) {
          await storeItem(serverItem);
          addedCount++;
        } else {
          final result = await _resolveConflict(localItem, serverItem);
          if (result == SyncConflictResult.stored ||
              result == SyncConflictResult.timestampUpdated) {
            updatedCount++;
          }
        }
      }

      developer.log(
        'GetAll sync completed: $addedCount added, $updatedCount updated, $deletedCount deleted, $serverDeletedCount sent to server for deletion',
        name: 'LocalDatabase',
      );

      if (deletedCount > 0 || updatedCount > 0 || addedCount > 0 || serverDeletedCount > 0) {
        return SyncConflictResult.stored;
      } else {
        return SyncConflictResult.noChanges;
      }
    } catch (e) {
      developer.log('Error handling getAll sync: $e', name: 'LocalDatabase');
      return SyncConflictResult.error;
    }
  }

  /// Handle incoming data from FCM or API with conflict resolution
  Future<SyncConflictResult> handleIncomingData(ISyncable incomingData) async {
    try {
      developer.log('Handling incoming data: ${incomingData.uuid}', name: 'LocalDatabase');

      final existingItem = await getItem(incomingData.tableName, incomingData.uuid);

      if (existingItem == null) {
        await storeItem(incomingData);

        developer.log('Stored new item: ${incomingData.uuid}', name: 'LocalDatabase');
        return SyncConflictResult.stored;
      }

      return await _resolveConflict(existingItem, incomingData);
    } catch (e) {
      developer.log('Error handling incoming data: $e', name: 'LocalDatabase');
      return SyncConflictResult.error;
    }
  }

  /// Resolve conflicts between local and incoming data
  Future<SyncConflictResult> _resolveConflict(ISyncable localItem, ISyncable incomingData) async {
    developer.log('Resolving conflict for: ${localItem.uuid}', name: 'LocalDatabase');

    timestampUpdated() async {
      final updatedItem = localItem.copyWith(
        oid: incomingData.oid,
        updatedAt: incomingData.updatedAt,
      );
      await storeItem(updatedItem);
      developer.log('Updated timestamps for: ${localItem.uuid}', name: 'LocalDatabase');
      return SyncConflictResult.timestampUpdated;
    }

    if (localItem.isNewerThan(incomingData)) {
      if (localItem.hasSameContentAs(incomingData)) {
        return timestampUpdated();
      } else {
        developer.log(
          'Local data is newer, needs server update: ${localItem.uuid}',
          name: 'LocalDatabase',
        );
        return SyncConflictResult.needsServerUpdate;
      }
    } else if (incomingData.isNewerThan(localItem)) {
      if (localItem.hasSameContentAs(incomingData)) {
        return timestampUpdated();
      } else {
        await storeItem(incomingData);
        developer.log('Stored newer incoming data for: ${localItem.uuid}', name: 'LocalDatabase');
        return SyncConflictResult.stored;
      }
    } else {
      // do nothing, timestamps are identical
      if (localItem.hasSameContentAs(incomingData)) {
        developer.log('No changes needed for: ${localItem.uuid}', name: 'LocalDatabase');
        return SyncConflictResult.noChanges;
      } else {
        await storeItem(incomingData);
        developer.log(
          'Timestamps identical but content differs, stored incoming data for: ${localItem.uuid}',
          name: 'LocalDatabase',
        );
        return SyncConflictResult.stored;
      }
    }
  }

  /// Monitor the fallback queue's responses and update local db accordingly
  Future<void> monitorFallbackQueue() async {
    Fallback.fallbackQueueStream.listen((event) async {
      print("Fallback event received: $event ${json.decode(event.response.body)}");
      final response = event.response;
      final type = event.type;
      final tableName = event.tableName;

      final modelPrototype = _findPrototypeByTableName(tableName)!;

      switch (type) {
        case RequestType.GET:
          final json = jsonDecode(response.body);
          final item = modelPrototype.fromServerData(json);
          handleIncomingData(item);
          break;
        case RequestType.GET_ALL:
          final List<dynamic> jsonList = json.decode(response.body);
          final List<ISyncable> items = [];
          for (final json in jsonList) items.add(modelPrototype.fromServerData(json));
          handleGetAllSync(tableName, items);
          break;
        case RequestType.POST:
          final responseJson = json.decode(response.body);
          final createdItem = modelPrototype.fromServerData(responseJson);
          handleIncomingData(createdItem);
          break;
        case RequestType.PUT:
          final responseJson = json.decode(response.body);
          final updatedItem = modelPrototype.fromServerData(responseJson);
          handleIncomingData(updatedItem);
          break;
        case RequestType.DELETE:
          deleteItem(tableName, event.uuid);
          break;
      }
    });
  }

  /// Update an existing item locally (will need to be synced)
  Future<ISyncable?> updateItem(String tableName, String uuid, ISyncable updatedItem) async {
    try {
      await storeItem(updatedItem);
      developer.log('Updated local item: $uuid', name: 'LocalDatabase');
      return updatedItem;
    } catch (e) {
      developer.log('Error updating item: $e', name: 'LocalDatabase');
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
        developer.log('Marked item as synced: $uuid with oid: $serverOid', name: 'LocalDatabase');
      }
    } catch (e) {
      developer.log('Error marking item as synced: $e', name: 'LocalDatabase');
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
      await (await _getBox(tableName)).clear();
      developer.log('Cleared table: $tableName', name: 'LocalDatabase');
    } catch (e) {
      developer.log('Error clearing table: $e', name: 'LocalDatabase');
    }
  }

  /// Get all registered table names
  List<String> getRegisteredTableNames() => SwanSync.tableNames;

  /// Close all boxes and cleanup
  Future<void> dispose() async => await Hive.close();
}

/// Result of sync conflict resolution
enum SyncConflictResult {
  stored, // stored incoming
  needsServerUpdate, // local is newer, update on server
  timestampUpdated, // superficial timestamp difference; local timestamp updated
  noChanges, // do nothing
  error, // something went wrong
}
