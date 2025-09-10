import 'package:swan_sync/data/repositories/firestore_item_repository.dart';
import 'package:swan_sync/business_logic/services/item_service.dart';
import 'package:swan_sync/data/repositories/i_item_repository.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final IItemRepository _itemRepository;
  late final ItemService _itemService;
  bool _hasBeenSetup = false;

  void setup() {
    if (_hasBeenSetup) return;
    _itemRepository = FirestoreItemRepository();
    _itemService = ItemService(_itemRepository);
    _hasBeenSetup = true;
  }

  ItemService get itemService => _itemService;
  IItemRepository get itemRepository => _itemRepository;
}
