// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_message_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataMessageResponse _$DataMessageResponseFromJson(Map<String, dynamic> json) =>
    DataMessageResponse(
      id: (json['id'] as num?)?.toInt(),
      entryId: (json['entryId'] as num?)?.toInt(),
      uuid: json['uuid'] as String,
      tableName: json['tableName'] as String,
      delete: json['delete'] as bool?,
    );

Map<String, dynamic> _$DataMessageResponseToJson(
        DataMessageResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entryId': instance.entryId,
      'uuid': instance.uuid,
      'tableName': instance.tableName,
      'delete': instance.delete,
    };
