import 'package:swan_sync/data/models/item_model.dart';
import 'package:swan_sync/communications/repositories/i_item_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

import 'package:swan_sync/main.dart';

class FirestoreItemRepository implements IItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Collections _collection = Collections.example;

  @override
  String getCurrentUserId() {
    return _auth.currentUser?.uid ?? MainApp.deviceName;
  }

  @override
  Stream<List<ItemModel>> getItems() {
    return _firestore
        .collection(_collection.name)
        .orderBy(ItemModelKeys.createdAt.name, descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ItemModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<void> addItem(String name) async {
    final userId = getCurrentUserId();
    final now = DateTime.now();

    final newItem = ItemModel(
      id: '', // document id automatically assigned by firestore
      name: name,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection(_collection.name).add(newItem.toFirestore());
  }

  @override
  Future<void> updateItem(String id, String name) async {
    final now = DateTime.now();

    await _firestore.collection(_collection.name).doc(id).update({
      ItemModelKeys.name.name: name,
      ItemModelKeys.userId.name: getCurrentUserId(),
      ItemModelKeys.updatedAt.name: now.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> deleteItem(String id) async {
    await _firestore.collection(_collection.name).doc(id).delete();
  }
}

enum Collections {
  example('collection_example', ItemModel);

  final String name;
  final Type dataType;
  const Collections(this.name, this.dataType);
}
