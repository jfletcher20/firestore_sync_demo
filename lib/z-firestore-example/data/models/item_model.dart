import 'package:swan_sync/z-firestore-example/data/i_data_model.dart';

class ItemModel implements IDataModel {
  final String id;
  final String name;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return ItemModel(
      id: documentId,
      name: data[ItemModelKeys.name.name] ?? '',
      userId: data[ItemModelKeys.userId.name] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data[ItemModelKeys.createdAt.name] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data[ItemModelKeys.updatedAt.name] ?? 0),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ItemModelKeys.name.name: name,
      ItemModelKeys.userId.name: userId,
      ItemModelKeys.createdAt.name: createdAt.millisecondsSinceEpoch,
      ItemModelKeys.updatedAt.name: updatedAt.millisecondsSinceEpoch,
    };
  }

  ItemModel copyWith({
    String? id,
    String? name,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          userId == other.userId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ userId.hashCode ^ createdAt.hashCode ^ updatedAt.hashCode;

  @override
  String toString() {
    return 'ItemModel{id: $id, name: $name, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}

enum ItemModelKeys { id, name, userId, createdAt, updatedAt }
