import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swan_sync/communications/managers/communications_manager.dart';
import 'package:swan_sync/data/i_syncable.dart';
import 'package:swan_sync/communications/services/local_database_service.dart';

abstract class FallbackManager {
  static const String _getQueueKey = 'fallback_queue_get';
  static const String _getAllQueueKey = 'fallback_queue_get_all';
  static const String _postQueueKey = 'fallback_queue_post';
  static const String _putQueueKey = 'fallback_queue_put';
  static const String _deleteQueueKey = 'fallback_queue_delete';
  static Timer? _retryTimer;
  static bool underway = false;

  static void init() {
    _startRetryTimer();
  }

  static String _getQueueKeyForType(RequestType type) {
    return switch (type) {
      RequestType.GET => _getQueueKey,
      RequestType.GET_ALL => _getAllQueueKey,
      RequestType.POST => _postQueueKey,
      RequestType.PUT => _putQueueKey,
      RequestType.DELETE => _deleteQueueKey,
    };
  }

  static Future<void> addToQueue(
    RequestType type,
    String tableName,
    String uuid,
    int? oid,
    ISyncable? data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = _getQueueKeyForType(type);
      final queueJson = prefs.getString(queueKey) ?? '[]';
      final List<dynamic> queue = json.decode(queueJson);

      final queueItem = {
        'type': type.name,
        'tableName': tableName,
        'uuid': uuid,
        'oid': oid,
        'data': data?.toServerData(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // queue.removeWhere((item) => item['uuid'] == uuid && item['tableName'] == tableName);
      queue.add(queueItem);

      await prefs.setString(queueKey, json.encode(queue));
      developer.log(
        'Added ${type.name} request for $uuid to ${type.name} queue',
        name: 'FallbackQueueManager',
      );
    } catch (e) {
      developer.log('Error adding to fallback queue: $e', name: 'FallbackQueueManager');
    }
  }

  static Future<bool> processQueues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int totalProcessed = 0;
      int totalRemaining = 0;

      for (final requestType in RequestType.values) {
        final queueKey = _getQueueKeyForType(requestType);
        final queueJson = prefs.getString(queueKey) ?? '[]';
        final List<dynamic> queue = json.decode(queueJson);

        if (queue.isEmpty) continue;

        developer.log(
          'Processing ${queue.length} items in ${requestType.name} queue',
          name: 'FallbackQueueManager',
        );
        final List<dynamic> remainingItems = [];

        for (final item in queue) {
          try {
            final success = await _retryQueueItem(item);
            if (!success) remainingItems.add(item);
          } catch (e) {
            developer.log(
              'Error processing ${requestType.name} queue item ${item['uuid']}: $e',
              name: 'FallbackQueueManager',
            );
            remainingItems.add(item);
          }
        }

        await prefs.setString(queueKey, json.encode(remainingItems));

        final processed = queue.length - remainingItems.length;
        totalProcessed += processed;
        totalRemaining += remainingItems.length;

        if (queue.isNotEmpty) {
          developer.log(
            '${requestType.name} queue: $processed processed, ${remainingItems.length} remaining',
            name: 'FallbackQueueManager',
          );
        }
      }

      if (totalProcessed > 0 || totalRemaining > 0) {
        developer.log(
          'Total: $totalProcessed items processed successfully, $totalRemaining remaining across all queues',
          name: 'FallbackQueueManager',
        );
      }
    } catch (e) {
      developer.log('Error processing fallback queues: $e', name: 'FallbackQueueManager');
    }
    underway = false;
    return true;
  }

  static Future<bool> _retryQueueItem(Map<String, dynamic> item) async {
    try {
      final type = RequestType.values.firstWhere((e) => e.name == item['type']);
      final tableName = item['tableName'] as String;
      final uuid = item['uuid'] as String;
      final oid = item['oid'] as int?;
      final dataJson = item['data'] as Map<String, dynamic>?;

      developer.log('Retrying ${type.name} request for $uuid', name: 'FallbackQueueManager');

      final localDb = LocalDatabaseService();
      final registeredTypes = localDb.registeredTypes;

      ISyncable? prototype;
      for (final registeredType in registeredTypes) {
        if (registeredType.tableName == tableName) {
          prototype = registeredType;
          break;
        }
      }

      if (prototype == null) {
        developer.log(
          'No registered type found for table: $tableName',
          name: 'FallbackQueueManager',
        );
        return false;
      }

      ISyncable? requestData;
      if (dataJson != null) {
        try {
          requestData = await localDb.getItem(prototype.tableName, uuid);
          print("Got item from local DB for retry: $requestData");
        } catch (e) {
          developer.log('Error reconstructing data from JSON: $e', name: 'FallbackQueueManager');
          return false;
        }
      }

      http.Response response;

      switch (type) {
        case RequestType.GET_ALL:
          response = await http.get(Uri.parse(prototype.getAllEndpoint));
          break;

        case RequestType.GET:
          if (oid == null) {
            developer.log('OID required for GET request', name: 'FallbackQueueManager');
            return false;
          }
          response = await http.get(Uri.parse('${prototype.getByIdEndpoint}/$oid'));
          break;

        case RequestType.POST:
          if (requestData == null) {
            developer.log('Data required for POST request', name: 'FallbackQueueManager');
            return false;
          }
          response = await http.post(
            Uri.parse(requestData.postEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData.toServerData()),
          );
          break;

        case RequestType.PUT:
          if (requestData == null || oid == null) {
            developer.log('Data and OID required for PUT request', name: 'FallbackQueueManager');
            return false;
          }
          response = await http.put(
            Uri.parse('${requestData.putEndpoint}/$oid'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData.toServerData()),
          );
          break;

        case RequestType.DELETE:
          if (oid == null) {
            developer.log('OID required for DELETE request', name: 'FallbackQueueManager');
            return false;
          }
          response = await http.delete(Uri.parse('${prototype.deleteEndpoint}/$oid'));
          break;
      }

      final success =
          (response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 404;

      if (success) {
        developer.log(
          'Successfully retried ${type.name} for $uuid (${response.statusCode})',
          name: 'FallbackQueueManager',
        );
        fallbackResponseStream.add((
          response: response,
          type: type,
          uuid: uuid,
          tableName: tableName,
        ));
      } else {
        developer.log(
          'Retry failed for ${type.name} $uuid (${response.statusCode}): ${response.body}',
          name: 'FallbackQueueManager',
        );
      }

      return success;
    } catch (e) {
      developer.log('Error retrying queue item: $e', name: 'FallbackQueueManager');
      return false;
    }
  }

  /// Store the fallback responses as a stream to be processed by local database service
  static final StreamController<
    ({http.Response response, RequestType type, String uuid, String tableName})
  >
  _fallbackResponseController = StreamController.broadcast();

  static Stream<({http.Response response, RequestType type, String uuid, String tableName})>
  get fallbackQueueStream => _fallbackResponseController.stream;

  static StreamSink<({http.Response response, RequestType type, String uuid, String tableName})>
  get fallbackResponseStream => _fallbackResponseController.sink;

  static Future<bool> currentRequestFinished = Future.value(true);
  static void _startRetryTimer() {
    if (_retryTimer?.isActive == true) return;

    _retryTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (underway)
        return;
      else
        underway = true;
      if (await currentRequestFinished) currentRequestFinished = processQueues();
    });

    developer.log('Started fallback queue retry timer', name: 'FallbackQueueManager');
  }

  static Future<int> getQueueSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int totalSize = 0;

      for (final requestType in RequestType.values) {
        final queueKey = _getQueueKeyForType(requestType);
        final queueJson = prefs.getString(queueKey) ?? '[]';
        final List<dynamic> queue = json.decode(queueJson);
        totalSize += queue.length;
      }

      return totalSize;
    } catch (e) {
      developer.log('Error getting queue size: $e', name: 'FallbackQueueManager');
      return 0;
    }
  }

  static Future<int> getQueueSizeForType(RequestType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = _getQueueKeyForType(type);
      final queueJson = prefs.getString(queueKey) ?? '[]';
      final List<dynamic> queue = json.decode(queueJson);
      return queue.length;
    } catch (e) {
      developer.log('Error getting queue size for ${type.name}: $e', name: 'FallbackQueueManager');
      return 0;
    }
  }
}
