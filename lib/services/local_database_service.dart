import 'dart:async';
import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sync_data_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  /// Initialize Hive and register adapters
  Future<void> initialize() async {
    developer.log('Initializing LocalDatabaseService', name: 'LocalDatabaseService');

    await Hive.initFlutter();

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SyncDataModelAdapter());
    }

    developer.log('LocalDatabaseService initialized', name: 'LocalDatabaseService');
  }

  /// Get or create a box for a specific table
  Future<Box<SyncDataModel>> _getBox(String tableName) async {
    if (!Hive.isBoxOpen(tableName)) {
      return await Hive.openBox<SyncDataModel>(tableName);
    }
    return Hive.box<SyncDataModel>(tableName);
  }

  /// Store or update an item in the local database
  Future<void> storeItem(SyncDataModel item) async {
    try {
      developer.log(
        'Storing item: ${item.uuid} in table: ${item.tableName}',
        name: 'LocalDatabaseService',
      );

      final box = await _getBox(item.tableName);
      await box.put(item.uuid, item);

      developer.log('Successfully stored item: ${item.uuid}', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error storing item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Get an item by UUID from a specific table
  Future<SyncDataModel?> getItem(String tableName, String uuid) async {
    try {
      final box = await _getBox(tableName);
      return box.get(uuid);
    } catch (e) {
      developer.log('Error getting item: $e', name: 'LocalDatabaseService');
      return null;
    }
  }

  /// Get all items from a specific table
  Future<List<SyncDataModel>> getAllItems(String tableName) async {
    try {
      final box = await _getBox(tableName);
      return box.values.where((item) => !item.isDeleted).toList();
    } catch (e) {
      developer.log('Error getting all items: $e', name: 'LocalDatabaseService');
      return [];
    }
  }

  /// Get items that need to be synced to the server
  Future<List<SyncDataModel>> getItemsNeedingSync(String tableName) async {
    try {
      final box = await _getBox(tableName);
      return box.values.where((item) => item.needsSync && !item.isDeleted).toList();
    } catch (e) {
      developer.log('Error getting items needing sync: $e', name: 'LocalDatabaseService');
      return [];
    }
  }

  /// Delete an item (soft delete by default)
  Future<void> deleteItem(String tableName, String uuid, {bool hardDelete = false}) async {
    try {
      developer.log(
        'Deleting item: $uuid from table: $tableName (hard: $hardDelete)',
        name: 'LocalDatabaseService',
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

      developer.log('Successfully deleted item: $uuid', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Handle incoming data from FCM or API with conflict resolution
  Future<SyncConflictResult> handleIncomingData(SyncDataModel incomingData) async {
    try {
      developer.log('Handling incoming data: ${incomingData.uuid}', name: 'LocalDatabaseService');

      final box = await _getBox(incomingData.tableName);
      final existingItem = box.get(incomingData.uuid);

      if (existingItem == null) {
        // No local copy exists, store the incoming data
        final itemToStore = incomingData.copyWith(needsSync: false);
        await box.put(incomingData.uuid, itemToStore);

        developer.log('Stored new item: ${incomingData.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.stored;
      }

      // Item exists locally, resolve conflict
      return await _resolveConflict(box, existingItem, incomingData);
    } catch (e) {
      developer.log('Error handling incoming data: $e', name: 'LocalDatabaseService');
      return SyncConflictResult.error;
    }
  }

  /// Resolve conflicts between local and incoming data
  Future<SyncConflictResult> _resolveConflict(
    Box<SyncDataModel> box,
    SyncDataModel localItem,
    SyncDataModel incomingData,
  ) async {
    developer.log('Resolving conflict for: ${localItem.uuid}', name: 'LocalDatabaseService');

    // If incoming data is a delete operation
    if (incomingData.isDeleted) {
      if (localItem.isNewerThan(incomingData)) {
        // Local item is newer, send update to server
        developer.log(
          'Local item is newer than delete, needs server update',
          name: 'LocalDatabaseService',
        );
        return SyncConflictResult.needsServerUpdate;
      } else {
        // Accept the delete
        await box.put(localItem.uuid, incomingData.copyWith(needsSync: false));
        developer.log('Accepted delete for: ${localItem.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.stored;
      }
    }

    // Compare timestamps
    if (localItem.isNewerThan(incomingData)) {
      // Local is newer
      if (localItem.hasSameDataAs(incomingData)) {
        // Same data, just update timestamps to match server
        final updatedItem = localItem.copyWith(updatedAt: incomingData.updatedAt, needsSync: false);
        await box.put(localItem.uuid, updatedItem);
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
    } else {
      // Incoming data is newer or same timestamp
      if (localItem.hasSameDataAs(incomingData)) {
        // Same data, just update timestamps
        final updatedItem = localItem.copyWith(updatedAt: incomingData.updatedAt, needsSync: false);
        await box.put(localItem.uuid, updatedItem);
        developer.log('Updated timestamps for: ${localItem.uuid}', name: 'LocalDatabaseService');
        return SyncConflictResult.timestampUpdated;
      } else {
        // Different data, incoming is newer - store incoming data
        final updatedItem = incomingData.copyWith(needsSync: false);
        await box.put(localItem.uuid, updatedItem);
        developer.log(
          'Stored newer incoming data for: ${localItem.uuid}',
          name: 'LocalDatabaseService',
        );
        return SyncConflictResult.stored;
      }
    }
  }

  /// Create a new item locally (will need to be synced)
  Future<SyncDataModel> createItem(String tableName, Map<String, dynamic> data) async {
    try {
      final now = DateTime.now();
      final item = SyncDataModel(
        uuid: _generateUuid(),
        tableName: tableName,
        data: data,
        createdAt: now,
        updatedAt: now,
        needsSync: true,
      );

      await storeItem(item);
      developer.log('Created new local item: ${item.uuid}', name: 'LocalDatabaseService');
      return item;
    } catch (e) {
      developer.log('Error creating item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Update an existing item locally (will need to be synced)
  Future<SyncDataModel?> updateItem(
    String tableName,
    String uuid,
    Map<String, dynamic> data,
  ) async {
    try {
      final box = await _getBox(tableName);
      final existingItem = box.get(uuid);

      if (existingItem == null) {
        developer.log('Item not found for update: $uuid', name: 'LocalDatabaseService');
        // then insert the item instead
        return await createItem(tableName, data);
      }

      final updatedItem = existingItem.copyWith(
        data: data,
        updatedAt: DateTime.now(),
        needsSync: true,
      );

      await box.put(uuid, updatedItem);
      developer.log('Updated local item: $uuid', name: 'LocalDatabaseService');
      return updatedItem;
    } catch (e) {
      developer.log('Error updating item: $e', name: 'LocalDatabaseService');
      rethrow;
    }
  }

  /// Mark an item as synced (no longer needs sync)
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
        developer.log('Marked item as synced: $uuid', name: 'LocalDatabaseService');
      }
    } catch (e) {
      developer.log('Error marking item as synced: $e', name: 'LocalDatabaseService');
    }
  }

  /// Get stream of changes for a specific table
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
      developer.log('Cleared table: $tableName', name: 'LocalDatabaseService');
    } catch (e) {
      developer.log('Error clearing table: $e', name: 'LocalDatabaseService');
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
