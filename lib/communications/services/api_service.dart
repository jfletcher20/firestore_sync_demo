import 'package:swan_sync/communications/services/sync_controller.dart';
import 'package:swan_sync/communications/managers/communications_manager.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:async';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const Duration timeout = Duration(seconds: 30);

  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'device-id': SyncController.deviceToken ?? 'anonymous swan v3',
  };

  /// List of registered ISyncable types for dynamic model creation
  final List<ISyncable> _registeredTypes = [];

  /// Register a syncable type for dynamic model creation
  void registerSyncableType(ISyncable prototype) {
    _registeredTypes.removeWhere((type) => type.tableName == prototype.tableName);
    _registeredTypes.add(prototype);
    developer.log('Registered syncable type: ${prototype.tableName}', name: 'ApiService');
  }

  /// Find the correct ISyncable prototype by table name
  ISyncable? _findPrototypeByTableName(String tableName) {
    try {
      return _registeredTypes.firstWhere((type) => type.tableName == tableName);
    } catch (e) {
      return null;
    }
  }

  /// Get all items for a specific syncable type
  Future<List<ISyncable>> getAll(ISyncable prototype) async {
    try {
      developer.log('Fetching all items for table: ${prototype.tableName}', name: 'ApiService');

      final response = await CommunicationsManager.handleRequest(
        prototype,
        null,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<ISyncable> items = [];

        for (final json in jsonList) {
          final String? tableName = json['tableName'];
          if (tableName == null) {
            throw ApiException('Server response missing tableName field: $json');
          }

          final modelPrototype = _findPrototypeByTableName(tableName);
          if (modelPrototype == null) {
            throw ApiException('No registered type found for tableName: $tableName');
          }

          items.add(modelPrototype.fromServerData(json));
        }

        developer.log(
          'Successfully fetched ${items.length} items for ${prototype.tableName}',
          name: 'ApiService',
        );
        return items;
      } else {
        throw ApiException('Failed to fetch data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching all data for ${prototype.tableName}: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Get item by ID for a specific syncable type
  Future<ISyncable> getById(ISyncable prototype, int id) async {
    try {
      developer.log(
        'Fetching item by ID: $id for table: ${prototype.tableName}',
        name: 'ApiService',
      );

      final response = await CommunicationsManager.handleRequest(
        prototype,
        null,
        oid: id,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final String? tableName = json['tableName'];
        if (tableName == null) {
          throw ApiException('Server response missing tableName field: $json');
        }

        final modelPrototype = _findPrototypeByTableName(tableName);
        if (modelPrototype == null) {
          throw ApiException('No registered type found for tableName: $tableName');
        }

        final item = modelPrototype.fromServerData(json);
        developer.log('Successfully fetched item: ${item.uuid}', name: 'ApiService');
        return item;
      } else if (response.statusCode == 404) {
        throw NotFoundException('Item not found: $id');
      } else {
        throw ApiException('Failed to fetch item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching item by ID: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Create new item
  Future<ISyncable> create(ISyncable data) async {
    try {
      developer.log('Creating item: ${data.uuid} for table: ${data.tableName}', name: 'ApiService');

      final response = await CommunicationsManager.handleRequest(
        data,
        data,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseJson = json.decode(response.body);

        final String? tableName = responseJson['tableName'];
        if (tableName == null) {
          throw ApiException('Server response missing tableName field: $responseJson');
        }

        final modelPrototype = _findPrototypeByTableName(tableName);
        if (modelPrototype == null) {
          throw ApiException('No registered type found for tableName: $tableName');
        }

        final createdItem = modelPrototype.fromServerData(responseJson);
        developer.log('Successfully created item: ${createdItem.oid}', name: 'ApiService');
        return createdItem;
      } else {
        throw ApiException('Failed to create item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error creating item: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Update existing item
  Future<ISyncable> update(ISyncable data, int id) async {
    try {
      developer.log('Updating item: $id for table: ${data.tableName}', name: 'ApiService');

      final response = await CommunicationsManager.handleRequest(
        data,
        data,
        oid: id,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        final responseJson = json.decode(response.body);

        final String? tableName = responseJson['tableName'];
        if (tableName == null) {
          throw ApiException('Server response missing tableName field: $responseJson');
        }

        final modelPrototype = _findPrototypeByTableName(tableName);
        if (modelPrototype == null) {
          throw ApiException('No registered type found for tableName: $tableName');
        }

        final updatedItem = modelPrototype.fromServerData(responseJson);
        developer.log('Successfully updated item: ${updatedItem.oid}', name: 'ApiService');
        return updatedItem;
      } else if (response.statusCode == 404) {
        throw NotFoundException('Item not found: $id');
      } else {
        throw ApiException('Failed to update item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error updating item: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Delete item
  Future<void> delete(ISyncable prototype, int id) async {
    try {
      developer.log('Deleting item: $id for table: ${prototype.tableName}', name: 'ApiService');

      final response = await CommunicationsManager.handleRequest(
        prototype,
        null,
        oid: id,
        delete: true,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        developer.log('Successfully deleted item: $id', name: 'ApiService');
      } else if (response.statusCode == 404) {
        throw NotFoundException('Item not found: $id');
      } else {
        throw ApiException('Failed to delete item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Check if the server is reachable for any registered type
  Future<bool> isServerReachable() async {
    if (_registeredTypes.isEmpty) return false;

    try {
      final prototype = _registeredTypes.first;
      final response = await CommunicationsManager.handleRequest(
        prototype,
        null,
        headers: _defaultHeaders,
      );
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Get all registered table names
  List<String> getRegisteredTableNames() {
    return _registeredTypes.map((type) => type.tableName).toList();
  }

  /// Get prototype for a table name
  ISyncable? getPrototypeForTable(String tableName) {
    return _findPrototypeByTableName(tableName);
  }
}

/// Base API exception
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Specific API exceptions
class NotFoundException extends ApiException {
  const NotFoundException(super.message);

  @override
  String toString() => 'NotFoundException: $message';
}

class NetworkException extends ApiException {
  const NetworkException(super.message);

  @override
  String toString() => 'NetworkException: $message';
}

class ServerException extends ApiException {
  const ServerException(super.message);

  @override
  String toString() => 'ServerException: $message';
}
