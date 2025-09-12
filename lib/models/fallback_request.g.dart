// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fallback_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FallbackRequestAdapter extends TypeAdapter<FallbackRequest> {
  @override
  final int typeId = 1;

  @override
  FallbackRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FallbackRequest(
      id: fields[0] as String,
      method: fields[1] as String,
      url: fields[2] as String,
      body: (fields[3] as Map?)?.cast<String, dynamic>(),
      headers: (fields[4] as Map?)?.cast<String, String>(),
      createdAt: fields[5] as DateTime,
      lastAttempt: fields[6] as DateTime,
      attemptCount: fields[7] as int,
      relatedUuid: fields[8] as String?,
      tableName: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FallbackRequest obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.method)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.headers)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastAttempt)
      ..writeByte(7)
      ..write(obj.attemptCount)
      ..writeByte(8)
      ..write(obj.relatedUuid)
      ..writeByte(9)
      ..write(obj.tableName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FallbackRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FallbackRequest _$FallbackRequestFromJson(Map<String, dynamic> json) =>
    FallbackRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      url: json['url'] as String,
      body: json['body'] as Map<String, dynamic>?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttempt: DateTime.parse(json['lastAttempt'] as String),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      relatedUuid: json['relatedUuid'] as String?,
      tableName: json['tableName'] as String,
    );

Map<String, dynamic> _$FallbackRequestToJson(FallbackRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'method': instance.method,
      'url': instance.url,
      'body': instance.body,
      'headers': instance.headers,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastAttempt': instance.lastAttempt.toIso8601String(),
      'attemptCount': instance.attemptCount,
      'relatedUuid': instance.relatedUuid,
      'tableName': instance.tableName,
    };
