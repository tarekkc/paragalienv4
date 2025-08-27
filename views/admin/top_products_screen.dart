import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:paragalien/providers/top_products_provider.dart'; // Create this provider

class TopProductsScreen extends ConsumerWidget {
  const TopProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topProducts = ref.watch(topProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Top Products Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Always show 5 slots
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final product = topProducts.firstWhere(
                    (p) => p.rank == rank,
                    orElse: () => TopProduct(
                      id: -1,
                      rank: rank,
                      productId: '',
                      productName: '',
                      color: TopProduct.getColorByRank(rank),
                    ),
                  );

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: product.color,
                        child: Text('$rank'),
                      ),
                      title: product.productName.isNotEmpty
                          ? Text(product.productName)
                          : const Text('Empty slot', style: TextStyle(color: Colors.grey)),
                      subtitle: product.productId.isNotEmpty
                          ? Text(product.productId)
                          : const Text('Click to add product'),
                      trailing: product.productName.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeProduct(ref, rank),
                            )
                          : null,
                      onTap: () => _showEditDialog(context, ref, rank),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProduct(WidgetRef ref, int rank) async {
    await ref.read(topProductsProvider.notifier).removeProduct(rank);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, int rank) {
    final product = ref.read(topProductsProvider).firstWhere(
      (p) => p.rank == rank,
      orElse: () => TopProduct(
        id: -1,
        rank: rank,
        productId: '',
        productName: '',
        color: TopProduct.getColorByRank(rank),
      ),
    );

    final idController = TextEditingController(text: product.productId);
    final nameController = TextEditingController(text: product.productName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Top $rank Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Product ID'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                await ref.read(topProductsProvider.notifier).saveProduct(
                  rank,
                  idController.text,
                  nameController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}