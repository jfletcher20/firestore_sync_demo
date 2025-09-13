import 'package:swan_sync/data/i_syncable.dart';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'todo_model.g.dart';

@HiveType(typeId: 0)
class TodoModel extends HiveObject implements ISyncable {
  @override
  @HiveField(0)
  final int oid;

  @override
  @HiveField(1)
  final String uuid;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String description;

  @override
  @HiveField(4)
  final DateTime createdAt;

  @override
  @HiveField(5)
  final DateTime updatedAt;

  TodoModel({
    this.oid = -1,
    required this.uuid,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new TodoModel with generated UUID
  factory TodoModel.create({required String name, required String description}) {
    final now = DateTime.now().toUtc();
    return TodoModel(
      uuid: const Uuid().v4(),
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a prototype instance for registration with services
  static TodoModel prototype() {
    return TodoModel(
      oid: -1,
      uuid: '',
      name: '',
      description: '',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  String get tableName => 'todos';

  @override
  bool get needsSync => oid == -1;

  @override
  bool isNewerThan(ISyncable other) {
    return updatedAt.isAfter(other.updatedAt);
  }

  // API Endpoints
  static const String host = 'http://192.168.100.77:8000/api';
  @override
  String get getAllEndpoint => '$host/v1/todos';

  @override
  String get getByIdEndpoint => '$host/v1/todos';

  @override
  String get postEndpoint => '$host/v1/todos';

  @override
  String get putEndpoint => '$host/v1/todos';

  @override
  String get deleteEndpoint => '$host/v1/todos';

  @override
  Map<String, dynamic> toServerData() {
    return {
      'uuid': uuid,
      'name': name,
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  ISyncable fromServerData(Map<String, dynamic> serverData) {
    return TodoModel(
      oid:
          int.tryParse(serverData['entryId']) ??
          int.tryParse(serverData['id']) ??
          int.tryParse(serverData['oid']) ??
          -1,
      uuid: serverData['uuid'] ?? '',
      name: serverData['name'] ?? '',
      description: serverData['description'] ?? '',
      createdAt: DateTime.tryParse(serverData['createdAt'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(serverData['updatedAt'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  @override
  ISyncable copyWith({
    int? oid,
    String? uuid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? description,
  }) {
    return TodoModel(
      oid: oid ?? this.oid,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool hasSameContentAs(ISyncable other) {
    if (other is! TodoModel) return false;
    return uuid == other.uuid && name == other.name && description == other.description;
  }

  @override
  Map<String, dynamic> toHiveData() {
    return {
      'oid': oid,
      'uuid': uuid,
      'name': name,
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  ISyncable fromHiveData(Map<String, dynamic> hiveData) {
    return TodoModel(
      oid: hiveData['oid'] ?? -1,
      uuid: hiveData['uuid'] ?? '',
      name: hiveData['name'] ?? '',
      description: hiveData['description'] ?? '',
      createdAt: DateTime.tryParse(hiveData['createdAt'] ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(hiveData['updatedAt'] ?? '') ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoModel &&
          runtimeType == other.runtimeType &&
          oid == other.oid &&
          uuid == other.uuid &&
          name == other.name &&
          description == other.description &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      oid.hashCode ^
      uuid.hashCode ^
      name.hashCode ^
      description.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'TodoModel{oid: $oid, uuid: $uuid, name: $name, description: $description, needsSync: $needsSync}';
  }
}
