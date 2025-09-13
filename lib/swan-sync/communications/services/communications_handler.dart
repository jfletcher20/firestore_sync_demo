// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swan_sync/swan-sync/data/i_syncable.dart';
import 'package:swan_sync/swan-sync/communications/services/local_database_service_refactored.dart';

abstract class CommunicationsHandler {
  // supposed to replace:
  /*
 
      final response = await http
          .get(Uri.parse(prototype.getAllEndpoint), headers: _defaultHeaders)
          .timeout(timeout);
          
      final response = await http
          .get(Uri.parse('${prototype.getByIdEndpoint}/$id'), headers: _defaultHeaders)
          .timeout(timeout);
      final body = json.encode(data.toServerData());
      final response = await http
          .post(Uri.parse(data.postEndpoint), headers: _defaultHeaders, body: body)
          .timeout(timeout);
      final body = json.encode(data.toServerData());
      final response = await http
          .put(Uri.parse('${data.putEndpoint}/$id'), headers: _defaultHeaders, body: body)
          .timeout(timeout);
      final response = await http
          .delete(Uri.parse('${prototype.deleteEndpoint}/$id'), headers: _defaultHeaders)
          .timeout(timeout);
          
          */
  // and add to shared prefs fallback-queues: "getQueue", "postQueue", "putQueue", "deleteQueue"; where it stores the data's tableName, uuid, and relevant data (for post/put), if the request fails! request type should be parsed via "RequestType" enum that has "detectType" based on args passed to it; all requests should go through master method: handleRequest(String endpoint, String tableName, {int? oid, headers, body})

  static Future<http.Response> handleRequest(
    ISyncable prototype,
    ISyncable? data, {
    int? oid,
    Map<String, String>? headers,
    bool delete = false,
  }) async {
    RequestType? type = RequestType.detectType(oid: oid, body: data != null, delete: delete);
    try {
      developer.log(
        'Handling request for table: ${prototype.tableName}',
        name: 'CommunicationsHandler',
      );

      http.Response response = switch (type) {
        RequestType.GET_ALL => await http
            .get(Uri.parse(prototype.getAllEndpoint), headers: headers)
            .timeout(const Duration(seconds: 10)),
        RequestType.GET => await http
            .get(Uri.parse('${prototype.getByIdEndpoint}/$oid'), headers: headers)
            .timeout(const Duration(seconds: 10)),
        RequestType.POST => await http
            .post(
              Uri.parse(data!.postEndpoint),
              headers: headers,
              body: json.encode(data.toServerData()),
            )
            .timeout(const Duration(seconds: 10)),
        RequestType.PUT => await http
            .put(
              Uri.parse('${data!.putEndpoint}/$oid'),
              headers: headers,
              body: json.encode(data.toServerData()),
            )
            .timeout(const Duration(seconds: 10)),
        RequestType.DELETE => await http
            .delete(Uri.parse('${prototype.deleteEndpoint}/$oid'), headers: headers)
            .timeout(const Duration(seconds: 10)),
        null =>
          throw Exception('Could not determine request type for table: ${prototype.tableName}'),
      };

      if ((response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 404) {
        return response;
      } else {
        developer.log(
          'Request failed for table: ${prototype.tableName}, status code: ${response.statusCode}, body: ${response.body}',
          name: 'CommunicationsHandler',
        );
        FallbackQueueManager.addToQueue(
          type!,
          prototype.tableName,
          data?.uuid ?? prototype.uuid,
          oid,
          data,
        );
        return response;
      }
    } catch (e) {
      developer.log(
        'Error handling request: $e, sending to fallback',
        name: 'CommunicationsHandler',
      );
      FallbackQueueManager.addToQueue(
        type!,
        prototype.tableName,
        data?.uuid ?? prototype.uuid,
        oid,
        data,
      );
      return http.Response('Error: $e', 500);
    }
  }
}

abstract class FallbackQueueManager {
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

  /// Get the queue key for a specific request type
  static String _getQueueKeyForType(RequestType type) {
    return switch (type) {
      RequestType.GET => _getQueueKey,
      RequestType.GET_ALL => _getAllQueueKey,
      RequestType.POST => _postQueueKey,
      RequestType.PUT => _putQueueKey,
      RequestType.DELETE => _deleteQueueKey,
    };
  }

  /// Add a failed request to the appropriate type-specific queue
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

      // Remove any existing item with same uuid in THIS queue type only
      queue.removeWhere((item) => item['uuid'] == uuid && item['tableName'] == tableName);
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

  /// Process all queued requests and retry them
  static Future<bool> processQueues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int totalProcessed = 0;
      int totalRemaining = 0;

      // Process each queue type separately
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

        // Update the specific queue with remaining items
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

  /// Retry a single queue item
  static Future<bool> _retryQueueItem(Map<String, dynamic> item) async {
    try {
      final type = RequestType.values.firstWhere((e) => e.name == item['type']);
      final tableName = item['tableName'] as String;
      final uuid = item['uuid'] as String;
      final oid = item['oid'] as int?;
      final dataJson = item['data'] as Map<String, dynamic>?;

      developer.log('Retrying ${type.name} request for $uuid', name: 'FallbackQueueManager');

      // Get the appropriate ISyncable prototype from LocalDatabaseService
      final localDb = LocalDatabaseService();
      final registeredTypes = localDb.registeredTypes;

      // Find the prototype for this table name
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

      // Prepare the request data
      ISyncable? requestData;
      if (dataJson != null) {
        try {
          requestData = await localDb.getItem(prototype!.tableName, uuid);
          print("Got item from local DB for retry: $requestData");
        } catch (e) {
          developer.log('Error reconstructing data from JSON: $e', name: 'FallbackQueueManager');
          return false;
        }
      }

      // Execute the appropriate HTTP request based on type
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

      // Check if the request was successful
      final success =
          (response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 404;

      if (success) {
        developer.log(
          'Successfully retried ${type.name} for $uuid (${response.statusCode})',
          name: 'FallbackQueueManager',
        );
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

  /// Start the periodic retry timer
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

  /// Get the current total queue size across all queues
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

  /// Get the queue size for a specific request type
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

  /// Clear all items from all queues
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final requestType in RequestType.values) {
        final queueKey = _getQueueKeyForType(requestType);
        await prefs.remove(queueKey);
      }

      developer.log('Cleared all fallback queues', name: 'FallbackQueueManager');
    } catch (e) {
      developer.log('Error clearing queues: $e', name: 'FallbackQueueManager');
    }
  }

  /// Clear items from a specific queue type
  static Future<void> clearQueueForType(RequestType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = _getQueueKeyForType(type);
      await prefs.remove(queueKey);
      developer.log('Cleared ${type.name} fallback queue', name: 'FallbackQueueManager');
    } catch (e) {
      developer.log('Error clearing ${type.name} queue: $e', name: 'FallbackQueueManager');
    }
  }
}

enum RequestType {
  GET,
  GET_ALL,
  POST,
  PUT,
  DELETE;

  static RequestType? detectType({int? oid, required bool body, bool delete = false}) {
    if (body && oid == null) {
      return RequestType.POST;
    } else if (body && oid != null) {
      return RequestType.PUT;
    } else if (!body && oid != null) {
      return delete ? RequestType.DELETE : RequestType.GET;
    } else if (!body && oid == null) {
      return RequestType.GET_ALL;
    }
    return null;
  }
}
