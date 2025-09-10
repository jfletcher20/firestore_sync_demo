import 'package:swan_sync/communications/repositories/i_item_repository.dart';
import 'package:swan_sync/data/models/item_model.dart';

import 'dart:async';

class ItemService {
  final IItemRepository _repository;
  const ItemService(this._repository);

  Stream<List<ItemModel>> getItems() => _repository.getItems();
  Future<void> createBlankItem() async => await _repository.addItem('New Item');
  Future<void> updateItemName(String id, String name) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Item name cannot be empty');
    }
    await _repository.updateItem(id, name.trim());
  }

  Future<void> deleteItem(String id) async => await _repository.deleteItem(id);
  String getCurrentUserId() => _repository.getCurrentUserId();
}
