import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fallback_request.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class FallbackRequest extends HiveObject {
  @HiveField(0)
  final String id; // Unique identifier for this request

  @HiveField(1)
  final String method; // GET, POST, PUT, DELETE

  @HiveField(2)
  final String url; // Full URL for the request

  @HiveField(3)
  final Map<String, dynamic>? body; // Request body (null for GET/DELETE)

  @HiveField(4)
  final Map<String, String>? headers; // Request headers

  @HiveField(5)
  final DateTime createdAt; // When this request was first created

  @HiveField(6)
  final DateTime lastAttempt; // When this request was last attempted

  @HiveField(7)
  final int attemptCount; // How many times we've tried this request

  @HiveField(8)
  final String? relatedUuid; // UUID of the data this request relates to

  @HiveField(9)
  final String tableName; // Which table/box this affects

  FallbackRequest({
    required this.id,
    required this.method,
    required this.url,
    this.body,
    this.headers,
    required this.createdAt,
    required this.lastAttempt,
    this.attemptCount = 0,
    this.relatedUuid,
    required this.tableName,
  });

  factory FallbackRequest.fromJson(Map<String, dynamic> json) => _$FallbackRequestFromJson(json);
  Map<String, dynamic> toJson() => _$FallbackRequestToJson(this);

  FallbackRequest copyWith({
    String? id,
    String? method,
    String? url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    DateTime? createdAt,
    DateTime? lastAttempt,
    int? attemptCount,
    String? relatedUuid,
    String? tableName,
  }) {
    return FallbackRequest(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      createdAt: createdAt ?? this.createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      attemptCount: attemptCount ?? this.attemptCount,
      relatedUuid: relatedUuid ?? this.relatedUuid,
      tableName: tableName ?? this.tableName,
    );
  }

  @override
  String toString() {
    return 'FallbackRequest{id: $id, method: $method, url: $url, attemptCount: $attemptCount, relatedUuid: $relatedUuid}';
  }
}
