import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/fallback_request.dart';
import '../models/sync_data_model.dart';
import 'api_service.dart';

class FallbackQueueService {
  static final FallbackQueueService _instance = FallbackQueueService._internal();
  factory FallbackQueueService() => _instance;
  FallbackQueueService._internal();

  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();

  // SharedPreferences keys for different request types
  static const String _getRequestsKey = 'fallback_get_requests';
  static const String _postRequestsKey = 'fallback_post_requests';
  static const String _putRequestsKey = 'fallback_put_requests';
  static const String _deleteRequestsKey = 'fallback_delete_requests';

  // Stream for broadcasting successful responses from fallback queue
  final StreamController<SyncDataModel> _fallbackResponseController =
      StreamController<SyncDataModel>.broadcast();
  Stream<SyncDataModel> get fallbackResponseStream => _fallbackResponseController.stream;

  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Initialize the fallback queue service
  Future<void> initialize() async {
    developer.log('Initializing FallbackQueueService', name: 'FallbackQueueService');

    // Start the retry timer (every 10 seconds)
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (_) => _processQueue());

    developer.log('FallbackQueueService initialized', name: 'FallbackQueueService');
  }

  /// Add a GET request to fallback queue
  Future<void> addGetRequest(String id, String tableName, {String? relatedUuid}) async {
    final request = FallbackRequest(
      id: _uuid.v4(),
      method: 'GET',
      url: '${ApiService.baseUrl}/$id',
      createdAt: DateTime.now(),
      lastAttempt: DateTime.now(),
      relatedUuid: relatedUuid,
      tableName: tableName,
    );

    await _addToQueue(_getRequestsKey, request);
    developer.log('Added GET request to fallback queue: $id', name: 'FallbackQueueService');
  }

  /// Add a POST request to fallback queue
  Future<void> addPostRequest(SyncDataModel data) async {
    final request = FallbackRequest(
      id: _uuid.v4(),
      method: 'POST',
      url: ApiService.baseUrl,
      body: data.toServerFormat(),
      createdAt: DateTime.now(),
      lastAttempt: DateTime.now(),
      relatedUuid: data.uuid,
      tableName: data.tableName,
    );

    await _addToQueue(_postRequestsKey, request);
    developer.log(
      'Added POST request to fallback queue: ${data.uuid}',
      name: 'FallbackQueueService',
    );
  }

  /// Add a PUT request to fallback queue
  Future<void> addPutRequest(String id, SyncDataModel data) async {
    final request = FallbackRequest(
      id: _uuid.v4(),
      method: 'PUT',
      url: '${ApiService.baseUrl}/$id',
      body: data.toServerFormat(),
      createdAt: DateTime.now(),
      lastAttempt: DateTime.now(),
      relatedUuid: data.uuid,
      tableName: data.tableName,
    );

    await _addToQueue(_putRequestsKey, request);
    developer.log('Added PUT request to fallback queue: $id', name: 'FallbackQueueService');
  }

  /// Add a DELETE request to fallback queue
  Future<void> addDeleteRequest(String id, String tableName, {String? relatedUuid}) async {
    final request = FallbackRequest(
      id: _uuid.v4(),
      method: 'DELETE',
      url: '${ApiService.baseUrl}/$id',
      createdAt: DateTime.now(),
      lastAttempt: DateTime.now(),
      relatedUuid: relatedUuid,
      tableName: tableName,
    );

    await _addToQueue(_deleteRequestsKey, request);
    developer.log('Added DELETE request to fallback queue: $id', name: 'FallbackQueueService');
  }

  /// Process all queued requests in priority order: GET, POST, PUT, DELETE
  Future<void> _processQueue() async {
    if (_isProcessing) {
      developer.log('Queue processing already in progress, skipping', name: 'FallbackQueueService');
      return;
    }

    _isProcessing = true;

    try {
      // Check if server is reachable before processing
      if (!await _apiService.isServerReachable()) {
        developer.log(
          'Server not reachable, skipping queue processing',
          name: 'FallbackQueueService',
        );
        return;
      }

      // Process in priority order
      await _processRequestsByType(_getRequestsKey, 'GET');
      await _processRequestsByType(_postRequestsKey, 'POST');
      await _processRequestsByType(_putRequestsKey, 'PUT');
      await _processRequestsByType(_deleteRequestsKey, 'DELETE');
    } catch (e) {
      developer.log('Error processing fallback queue: $e', name: 'FallbackQueueService');
    } finally {
      _isProcessing = false;
    }
  }

  /// Process requests of a specific type
  Future<void> _processRequestsByType(String key, String method) async {
    final requests = await _getQueuedRequests(key);
    if (requests.isEmpty) return;

    developer.log(
      'Processing ${requests.length} $method requests from fallback queue',
      name: 'FallbackQueueService',
    );

    final List<FallbackRequest> successfulRequests = [];
    final List<FallbackRequest> failedRequests = [];

    for (final request in requests) {
      try {
        final success = await _executeRequest(request);
        if (success) {
          successfulRequests.add(request);
        } else {
          failedRequests.add(
            request.copyWith(lastAttempt: DateTime.now(), attemptCount: request.attemptCount + 1),
          );
        }
      } catch (e) {
        developer.log('Failed to execute request ${request.id}: $e', name: 'FallbackQueueService');
        failedRequests.add(
          request.copyWith(lastAttempt: DateTime.now(), attemptCount: request.attemptCount + 1),
        );
      }
    }

    // Update the queue with failed requests (remove successful ones)
    await _updateQueue(key, failedRequests);

    if (successfulRequests.isNotEmpty) {
      developer.log(
        'Successfully executed ${successfulRequests.length} $method requests',
        name: 'FallbackQueueService',
      );
    }
  }

  /// Execute a specific request
  Future<bool> _executeRequest(FallbackRequest request) async {
    try {
      developer.log(
        'Executing ${request.method} request: ${request.url}',
        name: 'FallbackQueueService',
      );

      switch (request.method) {
        case 'GET':
          final id = request.url.split('/').last;
          final result = await _apiService.getById(id);
          _fallbackResponseController.add(result);
          return true;

        case 'POST':
          if (request.body == null) return false;
          final data = SyncDataModel.fromServerResponse(request.body!, request.tableName);
          final result = await _apiService.create(data);
          _fallbackResponseController.add(result);
          return true;

        case 'PUT':
          if (request.body == null) return false;
          final id = request.url.split('/').last;
          final data = SyncDataModel.fromServerResponse(request.body!, request.tableName);
          final result = await _apiService.update(id, data);
          _fallbackResponseController.add(result);
          return true;

        case 'DELETE':
          final id = request.url.split('/').last;
          await _apiService.delete(id);
          // For delete operations, create a deleted marker for the response stream
          if (request.relatedUuid != null) {
            final deletedMarker = SyncDataModel(
              entryId: id,
              uuid: request.relatedUuid!,
              tableName: request.tableName,
              data: {},
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isDeleted: true,
            );
            _fallbackResponseController.add(deletedMarker);
          }
          return true;

        default:
          developer.log('Unknown request method: ${request.method}', name: 'FallbackQueueService');
          return false;
      }
    } catch (e) {
      developer.log('Request execution failed: $e', name: 'FallbackQueueService');
      return false;
    }
  }

  /// Add a request to the specified queue
  Future<void> _addToQueue(String key, FallbackRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRequests = await _getQueuedRequests(key);
    existingRequests.add(request);

    final requestStrings = existingRequests.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(key, requestStrings);
  }

  /// Get all queued requests of a specific type
  Future<List<FallbackRequest>> _getQueuedRequests(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final requestStrings = prefs.getStringList(key) ?? [];

    return requestStrings
        .map((str) {
          try {
            final json = jsonDecode(str);
            return FallbackRequest.fromJson(json);
          } catch (e) {
            developer.log('Failed to parse fallback request: $e', name: 'FallbackQueueService');
            return null;
          }
        })
        .where((req) => req != null)
        .cast<FallbackRequest>()
        .toList();
  }

  /// Update the queue with the remaining failed requests
  Future<void> _updateQueue(String key, List<FallbackRequest> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final requestStrings = requests.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(key, requestStrings);
  }

  /// Get the total number of pending requests across all queues
  Future<int> getPendingRequestCount() async {
    final getRequests = await _getQueuedRequests(_getRequestsKey);
    final postRequests = await _getQueuedRequests(_postRequestsKey);
    final putRequests = await _getQueuedRequests(_putRequestsKey);
    final deleteRequests = await _getQueuedRequests(_deleteRequestsKey);

    return getRequests.length + postRequests.length + putRequests.length + deleteRequests.length;
  }

  /// Clear all fallback queues (for testing/debugging)
  Future<void> clearAllQueues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getRequestsKey);
    await prefs.remove(_postRequestsKey);
    await prefs.remove(_putRequestsKey);
    await prefs.remove(_deleteRequestsKey);

    developer.log('Cleared all fallback queues', name: 'FallbackQueueService');
  }

  /// Manually trigger queue processing
  Future<void> processQueueNow() async {
    developer.log('Manually triggering queue processing', name: 'FallbackQueueService');
    await _processQueue();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _fallbackResponseController.close();
  }
}
