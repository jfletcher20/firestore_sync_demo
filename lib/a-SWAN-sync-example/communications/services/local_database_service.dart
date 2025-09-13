import 'package:swan_sync/a-SWAN-sync-example/models/sync_data_model.dart';
import 'package:swan_sync/a-SWAN-sync-example/communications/services/api_service.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'dart:developer' as developer;
import 'dart:async';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static const String _service = 'LocalDatabaseService';

  /// Initialize Hive and register adapters
  Future<void> initialize({bool syncBetweenServer = false}) async {
    developer.log('Initializing $_service', name: _service);

    await Hive.initFlutter();

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SyncDataModelAdapter());
    }

    developer.log('$_service initialized', name: _service);
    if (syncBetweenServer) {
      await syncWithServer();
    }
  }

  /// Get or create a box for a specific table
  Future<Box<SyncDataModel>> _getBox(String tableName) async {
    if (!Hive.isBoxOpen(tableName)) return await Hive.openBox<SyncDataModel>(tableName);
    return Hive.box<SyncDataModel>(tableName);
  }

  /// Store or update an item in the local database
  Future<void> storeItem(SyncDataModel item) async {
    try {
      developer.log('Storing item: ${item.uuid} in table: ${item.tableName}', name: _service);
      final box = await _getBox(item.tableName);
      await box.put(item.uuid, item);
      developer.log('Successfully stored item: ${item.uuid}', name: _service);
    } catch (e) {
      developer.log('Error storing item: $e', name: _service);
      rethrow;
    }
  }

  /// Get an item by UUID from a specific table
  Future<SyncDataModel?> getItem(String tableName, String uuid) async {
    try {
      return (await _getBox(tableName)).get(uuid);
    } catch (e) {
      developer.log('Error getting item: $e', name: _service);
      return null;
    }
  }

  /// Get all items from a specific table
  Future<List<SyncDataModel>> getAllItems(String tableName) async {
    try {
      return (await _getBox(tableName)).values.where((item) => !item.isDeleted).toList();
    } catch (e) {
      developer.log('Error getting all items: $e', name: _service);
      return [];
    }
  }

  /// Get items that need to be synced to the server
  Future<List<SyncDataModel>> getItemsNeedingSync(String tableName) async {
    try {
      final box = await _getBox(tableName);
      return box.values.where((item) => item.needsSync && !item.isDeleted).toList();
    } catch (e) {
      developer.log('Error getting items needing sync: $e', name: _service);
      return [];
    }
  }

  /// Delete an item (soft delete by default)
  Future<void> deleteItem(String tableName, String uuid, {bool hardDelete = false}) async {
    try {
      developer.log(
        'Deleting item: $uuid from table: $tableName (hard: $hardDelete)',
        name: _service,
      );

      final box = await _getBox(tableName);

      if (hardDelete) {
        await box.delete(uuid);
      } else {
        final item = box.get(uuid);
        if (item != null) {
          final deletedItem = item.copyWith(
            isDeleted: true,
            updatedAt: DateTime.now(),
            needsSync: true,
          );
          await box.put(uuid, deletedItem);
        }
      }

      developer.log('Successfully deleted item: $uuid', name: _service);
    } catch (e) {
      developer.log('Error deleting item: $e', name: _service);
      rethrow;
    }
  }

  Future<void> syncWithServer() async {
    var serverItems = await ApiService().getAll();
    for (var serverItem in serverItems) handleIncomingData(serverItem);
  }

  /// Handle incoming data from FCM or API with conflict resolution
  Future<SyncConflictResult> handleIncomingData(SyncDataModel incomingData) async {
    try {
      developer.log('Handling incoming data: ${incomingData.uuid}', name: _service);

      var serverEntry = await ApiService().getById(incomingData.entryId ?? incomingData.oid ?? '');
      print('Server entry: $serverEntry');

      final box = await _getBox(incomingData.tableName);
      final existingItem = box.get(incomingData.uuid);

      if (existingItem == null) {
        final itemToStore = serverEntry.copyWith(needsSync: false);
        await box.put(serverEntry.uuid, itemToStore);
        developer.log('Stored new item: ${serverEntry.uuid}', name: _service);
        return SyncConflictResult.stored;
      }
      return await _resolveConflict(box, existingItem, serverEntry);
    } catch (e) {
      developer.log('Error handling incoming data: $e', name: _service);
      return SyncConflictResult.error;
    }
  }

  /// Resolve conflicts between local and incoming data
  Future<SyncConflictResult> _resolveConflict(
    Box<SyncDataModel> box,
    SyncDataModel localItem,
    SyncDataModel incomingData,
  ) async {
    developer.log('Resolving conflict for: ${localItem.uuid}', name: _service);
    Future<SyncConflictResult> handleTimestampUpdated() async {
      final updatedItem = localItem.copyWith(updatedAt: incomingData.updatedAt, needsSync: false);
      await box.put(localItem.uuid, updatedItem);
      developer.log('Updated timestamps for: ${localItem.uuid}', name: _service);
      return SyncConflictResult.timestampUpdated;
    }

    if (incomingData.isDeleted) {
      if (localItem.isNewerThan(incomingData)) {
        developer.log('Local item is newer than delete, needs server update', name: _service);
        return SyncConflictResult.needsServerUpdate;
      } else {
        await box.put(localItem.uuid, incomingData.copyWith(needsSync: false));
        developer.log('Accepted delete for: ${localItem.uuid}', name: _service);
        return SyncConflictResult.stored;
      }
    }
    if (localItem.isNewerThan(incomingData)) {
      if (localItem.hasSameDataAs(incomingData)) {
        return handleTimestampUpdated();
      } else {
        developer.log(
          'Local data is newer, needs server update: ${localItem.uuid}',
          name: _service,
        );
        return SyncConflictResult.needsServerUpdate;
      }
    } else {
      if (localItem.hasSameDataAs(incomingData)) {
        return handleTimestampUpdated();
      } else {
        final updatedItem = incomingData.copyWith(needsSync: false);
        await box.put(localItem.uuid, updatedItem);
        developer.log('Stored newer incoming data for: ${localItem.uuid}', name: _service);
        return SyncConflictResult.stored;
      }
    }
  }

  Future<SyncDataModel> createItem(String tableName, String name, String description) async {
    try {
      final now = DateTime.now();
      final item = SyncDataModel(
        uuid: _generateUuid(),
        tableName: tableName,
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
        needsSync: true,
      );
      await storeItem(item);
      developer.log('Created new local item: ${item.uuid}', name: _service);
      return item;
    } catch (e) {
      developer.log('Error creating item: $e', name: _service);
      rethrow;
    }
  }

  Future<SyncDataModel?> updateItem(
    String tableName,
    String uuid,
    String name,
    String description,
  ) async {
    try {
      final box = await _getBox(tableName);
      final existingItem = box.get(uuid);
      if (existingItem == null) {
        developer.log('Item not found for update: $uuid', name: _service);
        return await createItem(tableName, name, description);
      }

      final updatedItem = existingItem.copyWith(
        name: name,
        description: description,
        updatedAt: DateTime.now(),
        needsSync: true,
      );
      await box.put(uuid, updatedItem);
      developer.log('Updated local item: $uuid', name: _service);
      return updatedItem;
    } catch (e) {
      developer.log('Error updating item: $e', name: _service);
      rethrow;
    }
  }

  Future<void> markItemAsSynced(String tableName, String uuid, {String? serverEntryId}) async {
    try {
      final box = await _getBox(tableName);
      final item = box.get(uuid);
      if (item != null) {
        final syncedItem = item.copyWith(
          needsSync: false,
          entryId: serverEntryId ?? item.entryId,
          oid: serverEntryId ?? item.oid,
        );
        await box.put(uuid, syncedItem);
        developer.log('Marked item as synced: $uuid', name: _service);
      }
    } catch (e) {
      developer.log('Error marking item as synced: $e', name: _service);
    }
  }

  Stream<List<SyncDataModel>> watchTable(String tableName) {
    return Stream.fromFuture(_getBox(tableName)).asyncExpand(
      (box) => box.watch().map((_) => box.values.where((item) => !item.isDeleted).toList()),
    );
  }

  /// Clear all data for a specific table
  Future<void> clearTable(String tableName) async {
    try {
      final box = await _getBox(tableName);
      await box.clear();
      developer.log('Cleared table: $tableName', name: _service);
    } catch (e) {
      developer.log('Error clearing table: $e', name: _service);
    }
  }

  /// Close all boxes and cleanup
  Future<void> dispose() async {
    await Hive.close();
  }

  /// Generate a UUID for new items
  String _generateUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }
}

/// Result of sync conflict resolution
enum SyncConflictResult {
  stored, // Incoming data was stored
  needsServerUpdate, // Local data is newer, needs to be sent to server
  timestampUpdated, // Only timestamps were updated
  error, // An error occurred
}
