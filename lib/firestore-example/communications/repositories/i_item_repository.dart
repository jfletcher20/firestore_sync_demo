import 'package:swan_sync/firestore-example/data/models/item_model.dart';

abstract class IItemRepository {
  Stream<List<ItemModel>> getItems();
  Future<void> addItem(String name);
  Future<void> updateItem(String id, String name);
  Future<void> deleteItem(String id);
  String getCurrentUserId();
}
