import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/providers/commande_provider.dart';
import 'package:paragalien/views/admin/order_details_screen.dart';
import 'package:intl/intl.dart';
import '../../models/commande.dart';

final locationFilterProvider = StateProvider<String?>((ref) => null);

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allCommandesProvider);
    final selectedLocation = ref.watch(locationFilterProvider);

    Future<void> refreshOrders() async {
      ref.invalidate(allCommandesProvider);
    }

    List<Commande> filterOrders(List<Commande> orders) {
      if (selectedLocation == null || selectedLocation == 'all') return orders;
      return orders.where((order) {
        final locations = order.userProfile?.locations ?? [];
        return locations.any((loc) => loc.toLowerCase() == selectedLocation.toLowerCase());
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toutes les Commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => showFilterDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => _deleteOldOrders(context, ref),
        child: const Icon(Icons.delete_sweep),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur: $error')),
        data: (orders) => RefreshIndicator(
          onRefresh: refreshOrders,
          child: _buildOrderList(context, filterOrders(orders)),
        ),
      ),
    );
  }

  void showFilterDialog(BuildContext context, WidgetRef ref) {
    final selectedLocation = ref.watch(locationFilterProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrer par région'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: const Text('Toutes les régions'),
                value: 'all',
                groupValue: selectedLocation,
                onChanged: (value) {
                  ref.read(locationFilterProvider.notifier).state = value;
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String?>(
                title: const Text('Bouira'),
                value: 'bouira',
                groupValue: selectedLocation,
                onChanged: (value) {
                  ref.read(locationFilterProvider.notifier).state = value;
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String?>(
                title: const Text('Boumerdes'),
                value: 'boumerdes',
                groupValue: selectedLocation,
                onChanged: (value) {
                  ref.read(locationFilterProvider.notifier).state = value;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderList(BuildContext context, List<Commande> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('Aucune commande trouvée'),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (_, index) {
        final order = orders[index];
        final userName = order.userProfile?.name ?? 'Client inconnu';

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 4),
                Text(userName),
              ],
            ),
            subtitle: Row(
              children: [
                Text(DateFormat('dd/MM/yyyy').format(order.createdAt)),
                const Spacer(),
                Icon(
                  order.isApproved ? Icons.check_circle : Icons.access_time,
                  color: order.isApproved ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  order.isApproved ? 'Approuvée' : 'En attente',
                  style: TextStyle(
                    color: order.isApproved ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            trailing: Text('${order.items.length} Produits'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailsScreen(order: order),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

void _deleteOldOrders(BuildContext context, WidgetRef ref) async {
  final scaffold = ScaffoldMessenger.of(context);
  try {
    final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));
    await ref.read(commandeNotifierProvider).deleteOrdersOlderThan(fourDaysAgo);

    scaffold.showSnackBar(
      const SnackBar(content: Text('Commandes de plus de 4 jours supprimées')),
    );
    ref.invalidate(allCommandesProvider);
  } catch (e) {
    scaffold.showSnackBar(
      SnackBar(
        content: Text('Erreur: ${e.toString()}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}