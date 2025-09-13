// ignore_for_file: constant_identifier_names

import 'package:swan_sync/communications/managers/fallback_manager.dart';
import 'package:swan_sync/data/i_syncable.dart';

import 'package:http/http.dart' as http;

import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:async';

abstract class CommunicationsManager {
  static Future<http.Response> handleRequest(
    ISyncable prototype,
    ISyncable? data,
    String uuid, {
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
        FallbackManager.addToQueue(type!, prototype.tableName, uuid, oid, data);
        return response;
      }
    } catch (e) {
      developer.log(
        'Error handling request: $e, sending to fallback',
        name: 'CommunicationsHandler',
      );
      FallbackManager.addToQueue(type!, prototype.tableName, uuid, oid, data);
      return http.Response('Error: $e', 500);
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
