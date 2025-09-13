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
  final String name; // Name of the item

  @HiveField(9)
  final String description; // Description of the item

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
    required this.name,
    required this.description,
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
      name: payload['name'] ?? 'unknown',
      description: payload['description'] ?? '-',
      createdAt: DateTime.tryParse(payload['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(payload['updatedAt'] ?? '') ?? DateTime.now(),
      oid:
          payload['id']?.toString() ?? payload['oid']?.toString() ?? payload['entryId']?.toString(),
      isDeleted: payload['delete'] == 'true' || payload['delete'] == true,
    );
  }

  /// Create from server API response
  factory SyncDataModel.fromServerResponse(Map<String, dynamic> response, String tableName) {
    print('Server response: $response');
    return SyncDataModel(
      entryId: response['entryId'] ?? '',
      uuid: response['uuid'] ?? '',
      tableName: tableName,
      name: response['name'] ?? 'unknown',
      description: response['description'] ?? '-',
      createdAt: DateTime.tryParse(response['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(response['updatedAt'] ?? '') ?? DateTime.now(),
      oid:
          response['oid']?.toString() ??
          response['id']?.toString() ??
          response['entryId']?.toString(),
      isDeleted: response['delete'] == true || response['delete'] == 'true',
    );
  }

  Map<String, dynamic> toServerFormat() {
    return {
      'uuid': uuid,
      'tableName': tableName,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SyncDataModel copyWith({
    String? entryId,
    String? uuid,
    String? tableName,
    String? name,
    String? description,
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
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      oid: oid ?? this.oid,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  bool isNewerThan(SyncDataModel other) => updatedAt.isAfter(other.updatedAt);

  bool hasSameDataAs(SyncDataModel other) {
    return uuid == other.uuid &&
        name == other.name &&
        description == other.description &&
        isDeleted == other.isDeleted;
  }

  @override
  String toString() {
    return 'SyncDataModel{entryId: $entryId, uuid: $uuid, tableName: $tableName, name: $name, description: $description, oid: $oid, needsSync: $needsSync, isDeleted: $isDeleted}';
  }
}
