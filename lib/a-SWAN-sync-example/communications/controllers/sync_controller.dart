import 'package:swan_sync/a-SWAN-sync-example/communications/services/fallback_queue_service.dart';
import 'package:swan_sync/a-SWAN-sync-example/communications/services/local_database_service.dart';
import 'package:swan_sync/a-SWAN-sync-example/communications/services/fcm_messaging_service.dart';
import 'package:swan_sync/a-SWAN-sync-example/models/sync_data_model.dart';
import 'package:swan_sync/a-SWAN-sync-example/communications/services/api_service.dart';

import 'dart:developer' as developer;
import 'dart:async';

class SyncController {
  static final SyncController _instance = SyncController._internal();
  factory SyncController() => _instance;
  SyncController._internal();

  final FcmMessagingService _fcmService = FcmMessagingService();
  final ApiService _apiService = ApiService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final FallbackQueueService _fallbackQueue = FallbackQueueService();

  StreamSubscription<SyncDataModel>? _fcmSubscription;
  StreamSubscription<SyncDataModel>? _fallbackSubscription;

  /// Initialize the sync controller and set up listeners
  Future<void> initialize() async {
    developer.log('Initializing SyncController', name: 'SyncController');
    _fcmSubscription = _fcmService.dataMessageStream.listen(
      _handleFcmMessage,
      onError: (error) => developer.log('Error in FCM stream: $error', name: 'SyncController'),
    );
    _fallbackSubscription = _fallbackQueue.fallbackResponseStream.listen(
      _handleFallbackResponse,
      onError: (error) {
        developer.log('Error in fallback response stream: $error', name: 'SyncController');
      },
    );
    developer.log('SyncController initialized', name: 'SyncController');
  }

  Future<void> _handleFcmMessage(SyncDataModel incomingData) async {
    try {
      developer.log('Handling FCM message for: ${incomingData.uuid}', name: 'SyncController');
      // delete operation
      if (incomingData.isDeleted) {
        await _handleDeleteOperation(incomingData);
        return;
      }
      // create or update operation
      final result = await _localDb.handleIncomingData(incomingData);
      switch (result) {
        case SyncConflictResult.stored:
        case SyncConflictResult.timestampUpdated:
          developer.log(
            'Successfully handled FCM data: ${incomingData.uuid}',
            name: 'SyncController',
          );
          break;
        case SyncConflictResult.needsServerUpdate:
          developer.log(
            'Local data is newer, sending to server: ${incomingData.uuid}',
            name: 'SyncController',
          );
          await _sendLocalDataToServer(incomingData.tableName, incomingData.uuid);
          break;
        case SyncConflictResult.error:
          developer.log('Error handling FCM data: ${incomingData.uuid}', name: 'SyncController');
          break;
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
  Future<void> _handleDeleteOperation(SyncDataModel deleteData) async {
    try {
      developer.log('Handling delete operation for: ${deleteData.uuid}', name: 'SyncController');

      final localItem = await _localDb.getItem(deleteData.tableName, deleteData.uuid);

      if (localItem == null) {
        developer.log(
          'Delete operation for non-existent item: ${deleteData.uuid}',
          name: 'SyncController',
        );
        return;
      }
      await _localDb.deleteItem(deleteData.tableName, deleteData.uuid, hardDelete: true);
      developer.log('Accepted delete for: ${deleteData.uuid}', name: 'SyncController');
    } catch (e) {
      developer.log('Error handling delete operation: $e', name: 'SyncController');
    }
  }

  /// Handle responses from the fallback queue
  Future<void> _handleFallbackResponse(SyncDataModel responseData) async {
    try {
      developer.log('Handling fallback response for: ${responseData.uuid}', name: 'SyncController');

      if (responseData.isDeleted) {
        await _localDb.deleteItem(responseData.tableName, responseData.uuid, hardDelete: true);
      } else {
        await _localDb.handleIncomingData(responseData);
        if (responseData.entryId != null) {
          await _localDb.markItemAsSynced(
            responseData.tableName,
            responseData.uuid,
            serverEntryId: responseData.entryId,
          );
        }
      }
    } catch (e) {
      developer.log('Error handling fallback response: $e', name: 'SyncController');
    }
  }

  Future<void> _sendLocalDataToServer(String tableName, String uuid) async {
    try {
      final localItem = await _localDb.getItem(tableName, uuid);
      if (localItem == null) {
        developer.log('Local item not found for server update: $uuid', name: 'SyncController');
        return;
      }
      if (localItem.entryId != null && localItem.entryId!.isNotEmpty)
        await _updateOnServer(localItem);
      else
        await _createOnServer(localItem);
    } catch (e) {
      developer.log('Error sending local data to server: $e', name: 'SyncController');
    }
  }

  /// Create a new item on the server
  Future<void> _createOnServer(SyncDataModel localItem) async {
    try {
      developer.log('Creating item on server: ${localItem.uuid}', name: 'SyncController');

      final result = await _apiService.create(localItem);
      await _localDb.markItemAsSynced(
        localItem.tableName,
        localItem.uuid,
        serverEntryId: result.entryId,
      );

      developer.log(
        'Successfully created item on server: ${result.entryId}',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log(
        'Failed to create item on server, adding to fallback queue: $e',
        name: 'SyncController',
      );
      await _fallbackQueue.addPostRequest(localItem);
    }
  }

  /// Update an existing item on the server
  Future<void> _updateOnServer(SyncDataModel localItem) async {
    try {
      developer.log('Updating item on server: ${localItem.entryId}', name: 'SyncController');

      final result = await _apiService.update(localItem.entryId!, localItem);
      await _localDb.markItemAsSynced(
        localItem.tableName,
        localItem.uuid,
        serverEntryId: result.entryId,
      );

      developer.log(
        'Successfully updated item on server: ${result.entryId}',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log(
        'Failed to update item on server, adding to fallback queue: $e',
        name: 'SyncController',
      );
      await _fallbackQueue.addPutRequest(localItem.entryId!, localItem);
    }
  }

  /// Create a new item locally (user-initiated)
  Future<SyncDataModel> createLocalItem(String tableName, String name, String description) async {
    try {
      developer.log('Creating local item in table: $tableName', name: 'SyncController');

      final localItem = await _localDb.createItem(tableName, name, description);

      // Try to sync to server immediately
      await _createOnServer(localItem);

      return localItem;
    } catch (e) {
      developer.log('Error creating local item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Update an existing item locally (user-initiated)
  Future<SyncDataModel?> updateLocalItem(
    String tableName,
    String uuid,
    String name,
    String description,
  ) async {
    try {
      developer.log('Updating local item: $uuid', name: 'SyncController');

      final updatedItem = await _localDb.updateItem(tableName, uuid, name, description);
      if (updatedItem == null) return null;

      // Try to sync to server immediately
      if (updatedItem.entryId != null && updatedItem.entryId!.isNotEmpty) {
        await _updateOnServer(updatedItem);
      } else {
        await _createOnServer(updatedItem);
      }

      return updatedItem;
    } catch (e) {
      developer.log('Error updating local item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Delete an item locally (user-initiated)
  Future<void> deleteLocalItem(String tableName, String uuid) async {
    try {
      developer.log('Deleting local item: $uuid', name: 'SyncController');

      final localItem = await _localDb.getItem(tableName, uuid);
      if (localItem == null) {
        developer.log('Item not found for deletion: $uuid', name: 'SyncController');
        return;
      }

      // Delete locally first
      await _localDb.deleteItem(tableName, uuid, hardDelete: true);

      // Try to delete on server if it has a server ID
      if (localItem.entryId != null && localItem.entryId!.isNotEmpty) {
        try {
          await _apiService.delete(localItem.entryId!);
          developer.log(
            'Successfully deleted item on server: ${localItem.entryId}',
            name: 'SyncController',
          );
        } catch (e) {
          developer.log(
            'Failed to delete item on server, adding to fallback queue: $e',
            name: 'SyncController',
          );
          await _fallbackQueue.addDeleteRequest(localItem.entryId!, tableName, relatedUuid: uuid);
        }
      }
    } catch (e) {
      developer.log('Error deleting local item: $e', name: 'SyncController');
      rethrow;
    }
  }

  /// Get all items from a specific table
  Future<List<SyncDataModel>> getItems(String tableName) async {
    return await _localDb.getAllItems(tableName);
  }

  /// Get stream of items for a specific table
  Stream<List<SyncDataModel>> watchItems(String tableName) {
    var stream = _localDb.watchTable(tableName);
    var currentItems = getItems(tableName);
    // remove from currentItems any items that are in stream, or that are marked as deleted
    currentItems.then((items) {
      items.removeWhere((item) => item.isDeleted);
    });
    var returnStream = Stream<List<SyncDataModel>>.multi((controller) async {
      await for (var items in stream) {
        items.removeWhere((item) => item.isDeleted);
        controller.add(items);
      }
      var initialItems = await currentItems;
      controller.add(initialItems);
    });
    return returnStream;
  }

  /// Manually trigger sync for items that need syncing
  Future<void> syncPendingItems(String tableName) async {
    try {
      developer.log('Syncing pending items for table: $tableName', name: 'SyncController');

      final pendingItems = await _localDb.getItemsNeedingSync(tableName);

      for (final item in pendingItems) {
        if (item.entryId != null && item.entryId!.isNotEmpty) {
          await _updateOnServer(item);
        } else {
          await _createOnServer(item);
        }
      }

      developer.log(
        'Finished syncing ${pendingItems.length} pending items',
        name: 'SyncController',
      );
    } catch (e) {
      developer.log('Error syncing pending items: $e', name: 'SyncController');
    }
  }

  /// Get the count of pending requests in fallback queue
  Future<int> getPendingRequestCount() async {
    return await _fallbackQueue.getPendingRequestCount();
  }

  /// Manually trigger fallback queue processing
  Future<void> processFallbackQueue() async {
    await _fallbackQueue.processQueueNow();
  }

  /// Check if server is reachable
  Future<bool> isServerReachable() async {
    return await _apiService.isServerReachable();
  }

  /// Dispose resources
  void dispose() {
    _fcmSubscription?.cancel();
    _fallbackSubscription?.cancel();
  }
}
