import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/sync_data_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'http://10.85.9.186:8000/api/v1/sync';
  static const Duration timeout = Duration(seconds: 30);

  final Map<String, String> _defaultHeaders = {'Content-Type': 'application/json'};

  /// Get all sync data
  Future<List<SyncDataModel>> getAll() async {
    try {
      developer.log('Fetching all sync data', name: 'ApiService');

      final response = await http
          .get(Uri.parse(baseUrl), headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<SyncDataModel> items =
            jsonList
                .map(
                  (json) => SyncDataModel.fromServerResponse(json, json['tableName'] ?? 'testData'),
                )
                .toList();

        developer.log('Successfully fetched ${items.length} items', name: 'ApiService');
        return items;
      } else {
        throw ApiException('Failed to fetch data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching all data: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Get sync data by ID
  Future<SyncDataModel> getById(String id) async {
    try {
      developer.log('Fetching sync data by ID: $id', name: 'ApiService');

      final response = await http
          .get(Uri.parse('$baseUrl/$id'), headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final item = SyncDataModel.fromServerResponse(
          json['data'],
          json['tableName'] ?? 'testData',
        );

        developer.log('Successfully fetched item: $item', name: 'ApiService');
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

  /// Create new sync data
  Future<SyncDataModel> create(SyncDataModel data) async {
    try {
      developer.log('Creating sync data: ${data.uuid}', name: 'ApiService');

      final body = json.encode(data.toServerFormat());
      final response = await http
          .post(Uri.parse(baseUrl), headers: _defaultHeaders, body: body)
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseJson = json.decode(response.body);
        final createdItem = SyncDataModel.fromServerResponse(responseJson, data.tableName);

        developer.log('Successfully created item: ${createdItem.entryId}', name: 'ApiService');
        return createdItem;
      } else {
        throw ApiException('Failed to create item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error creating item: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Update sync data
  Future<SyncDataModel> update(String id, SyncDataModel data) async {
    try {
      developer.log('Updating sync data: $id', name: 'ApiService');

      final body = json.encode(data.toServerFormat());
      final response = await http
          .put(Uri.parse('$baseUrl/$id'), headers: _defaultHeaders, body: body)
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseJson = json.decode(response.body);
        final updatedItem = SyncDataModel.fromServerResponse(responseJson, data.tableName);

        developer.log('Successfully updated item: ${updatedItem.entryId}', name: 'ApiService');
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

  /// Delete sync data
  Future<void> delete(String id) async {
    try {
      developer.log('Deleting sync data: $id', name: 'ApiService');

      final response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        developer.log('Successfully deleted item: $id', name: 'ApiService');
      } else if (response.statusCode == 404) {
        developer.log('Item not found: $id; that\'s fine', name: 'ApiService');
      } else {
        throw ApiException('Failed to delete item: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error deleting item: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Get Firebase IDs (debug endpoint)
  Future<List<String>> getFirebaseIds() async {
    try {
      developer.log('Fetching Firebase IDs', name: 'ApiService');

      final response = await http
          .get(Uri.parse('$baseUrl/debug/firebase-ids'), headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<String> ids = jsonList.cast<String>();

        developer.log('Successfully fetched ${ids.length} Firebase IDs', name: 'ApiService');
        return ids;
      } else {
        throw ApiException('Failed to fetch Firebase IDs: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error fetching Firebase IDs: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Clear all data (debug endpoint)
  Future<void> clearAll() async {
    try {
      developer.log('Clearing all data', name: 'ApiService');

      final response = await http
          .post(Uri.parse('$baseUrl/debug/clear'), headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        developer.log('Successfully cleared all data', name: 'ApiService');
      } else {
        throw ApiException('Failed to clear data: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      developer.log('Error clearing data: $e', name: 'ApiService');
      rethrow;
    }
  }

  /// Check if the server is reachable
  Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl), headers: _defaultHeaders)
          .timeout(Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
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
