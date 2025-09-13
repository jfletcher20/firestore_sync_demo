import 'package:json_annotation/json_annotation.dart';

part 'data_message_response.g.dart';

/// Model for handling FCM data message responses
/// Contains minimal data needed to identify and process sync messages
@JsonSerializable()
class DataMessageResponse {
  /// Server-side entry ID (can be null for new items)
  @JsonKey(name: 'id')
  final int? id;

  /// Alternative name for server ID (entryId/oid)
  final int? entryId;

  /// Client-side UUID
  final String uuid;

  /// Table name to identify which model type this belongs to
  final String tableName;

  /// Whether this is a delete operation
  final bool? delete;

  DataMessageResponse({
    this.id,
    this.entryId,
    required this.uuid,
    required this.tableName,
    this.delete,
  });

  /// Factory constructor from JSON
  factory DataMessageResponse.fromJson(Map<String, dynamic> json) =>
      _$DataMessageResponseFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$DataMessageResponseToJson(this);

  /// Create from FCM data payload
  factory DataMessageResponse.fromFcmPayload(Map<String, dynamic> payload) {
    return DataMessageResponse(
      id: int.tryParse(payload['id']?.toString() ?? ''),
      entryId: int.tryParse(payload['entryId']?.toString() ?? ''),
      uuid: payload['uuid'] ?? '',
      tableName: payload['tableName'] ?? '',
      delete: payload['delete'] == 'true' || payload['delete'] == true,
    );
  }

  /// Get the effective ID (prioritize entryId over id)
  int? get effectiveId => entryId ?? id;

  /// Check if this is a delete operation
  bool get isDelete => delete == true;

  @override
  String toString() {
    return 'DataMessageResponse{id: $id, entryId: $entryId, uuid: $uuid, tableName: $tableName, delete: $delete}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataMessageResponse &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entryId == other.entryId &&
          uuid == other.uuid &&
          tableName == other.tableName &&
          delete == other.delete;

  @override
  int get hashCode =>
      id.hashCode ^ entryId.hashCode ^ uuid.hashCode ^ tableName.hashCode ^ delete.hashCode;
}
