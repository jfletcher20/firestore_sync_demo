import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sync_data_model.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class SyncDataModel extends HiveObject {
  @HiveField(0)
  final String? entryId; // Server-side ID (also stored as oid)

  @HiveField(1)
  final String uuid; // Client-side UUID

  @HiveField(2)
  final String tableName; // Which Hive box this belongs to

  @HiveField(3)
  final Map<String, dynamic> data; // The actual data payload

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final String? oid; // Online ID - same as entryId but explicitly stored

  @HiveField(7)
  final bool isDeleted; // Soft delete flag

  @HiveField(8)
  final bool needsSync; // Whether this item needs to be synced to server

  SyncDataModel({
    this.entryId,
    required this.uuid,
    required this.tableName,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.oid,
    this.isDeleted = false,
    this.needsSync = false,
  });

  factory SyncDataModel.fromJson(Map<String, dynamic> json) => _$SyncDataModelFromJson(json);
  Map<String, dynamic> toJson() => _$SyncDataModelToJson(this);

  /// Create from FCM data message payload
  factory SyncDataModel.fromFcmPayload(Map<String, dynamic> payload) {
    return SyncDataModel(
      entryId: payload['entryId']?.toString(),
      uuid: payload['uuid'] ?? '',
      tableName: payload['tableName'] ?? 'unknown',
      data: payload['data'] ?? {},
      createdAt: DateTime.tryParse(payload['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(payload['updatedAt'] ?? '') ?? DateTime.now(),
      oid: payload['id']?.toString() ?? payload['oid']?.toString(),
      isDeleted: payload['delete'] == 'true' || payload['delete'] == true,
    );
  }

  /// Create from server API response
  factory SyncDataModel.fromServerResponse(Map<String, dynamic> response, String tableName) {
    print('Server response: $response');
    return SyncDataModel(
      entryId: response['entryId']?.toString() ?? response['id']?.toString(),
      uuid: response['uuid'] ?? '',
      tableName: tableName,
      data: response['data'] ?? response,
      createdAt: DateTime.tryParse(response['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(response['updatedAt'] ?? '') ?? DateTime.now(),
      oid:
          response['id']?.toString() ??
          response['oid']?.toString() ??
          response['entryId']?.toString(),
      isDeleted: response['delete'] == true || response['delete'] == 'true',
    );
  }

  /// Convert to server API format
  Map<String, dynamic> toServerFormat() {
    return {
      'uuid': uuid,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  SyncDataModel copyWith({
    String? entryId,
    String? uuid,
    String? tableName,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? oid,
    bool? isDeleted,
    bool? needsSync,
  }) {
    return SyncDataModel(
      entryId: entryId ?? this.entryId,
      uuid: uuid ?? this.uuid,
      tableName: tableName ?? this.tableName,
      data: data ?? Map<String, dynamic>.from(this.data),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      oid: oid ?? this.oid,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  /// Check if this item is newer than another
  bool isNewerThan(SyncDataModel other) {
    return updatedAt.isAfter(other.updatedAt);
  }

  /// Check if the data content is the same (ignoring timestamps)
  bool hasSameDataAs(SyncDataModel other) {
    return uuid == other.uuid && _mapEquals(data, other.data) && isDeleted == other.isDeleted;
  }

  bool _mapEquals(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (String key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    return 'SyncDataModel{entryId: $entryId, uuid: $uuid, tableName: $tableName, oid: $oid, needsSync: $needsSync, isDeleted: $isDeleted}';
  }
}
