// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_data_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncDataModelAdapter extends TypeAdapter<SyncDataModel> {
  @override
  final int typeId = 0;

  @override
  SyncDataModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncDataModel(
      entryId: fields[0] as String?,
      uuid: fields[1] as String,
      tableName: fields[2] as String,
      data: (fields[3] as Map).cast<String, dynamic>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      oid: fields[6] as String?,
      isDeleted: fields[7] as bool,
      needsSync: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SyncDataModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.entryId)
      ..writeByte(1)
      ..write(obj.uuid)
      ..writeByte(2)
      ..write(obj.tableName)
      ..writeByte(3)
      ..write(obj.data)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.oid)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.needsSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDataModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncDataModel _$SyncDataModelFromJson(Map<String, dynamic> json) =>
    SyncDataModel(
      entryId: json['entryId'] as String?,
      uuid: json['uuid'] as String,
      tableName: json['tableName'] as String,
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      oid: json['oid'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
    );

Map<String, dynamic> _$SyncDataModelToJson(SyncDataModel instance) =>
    <String, dynamic>{
      'entryId': instance.entryId,
      'uuid': instance.uuid,
      'tableName': instance.tableName,
      'data': instance.data,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'oid': instance.oid,
      'isDeleted': instance.isDeleted,
      'needsSync': instance.needsSync,
    };
