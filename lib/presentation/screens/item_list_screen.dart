import 'package:swan_sync/presentation/widgets/synced_list_view.dart';
import 'package:swan_sync/presentation/widgets/snapshot_error.dart';
import 'package:swan_sync/presentation/widgets/no_items.dart';
import 'package:swan_sync/data/core/service_locator.dart';
import 'package:swan_sync/data/models/item_model.dart';

import 'package:flutter/material.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final _itemService = ServiceLocator().itemService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore demo', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: StreamBuilder<List<ItemModel>>(
        stream: _itemService.getItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return SnapshotError(snapshot);
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if ((snapshot.data ?? []).isEmpty) return const NoItems();
          return SyncedListView(items: snapshot.data!, onUpdate: _update, onDelete: _delete);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(String message) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Function errorHandler(String action) {
    return (Object e) {
      if (mounted) error('Failed to $action item: $e');
    };
  }

  Future<void> _addItem() async {
    await _itemService.createBlankItem().catchError(errorHandler('add'));
  }

  Future<void> _update(String id, String name) async {
    await _itemService.updateItemName(id, name).catchError(errorHandler('update'));
  }

  Future<void> _delete(String id) async {
    await _itemService.deleteItem(id).catchError(errorHandler('delete'));
  }
}
