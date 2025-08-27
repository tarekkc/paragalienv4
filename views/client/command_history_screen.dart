import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/history_provider.dart';
import '../../models/orderhistory.dart';

class CommandHistoryScreen extends ConsumerWidget {
  final String userId;

  const CommandHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des commandes'),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading orders',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(error.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('No orders found', style: TextStyle(fontSize: 18)),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildOrderCard(context, ref, orders[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, OrderHistory order) {
    final total = order.items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final shortId = order.id.length > 8
        ? '${order.id.substring(0, 4)}...${order.id.substring(order.id.length - 4)}'
        : order.id;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(context, ref, order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.userName ?? "Unknown"}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commande #$shortId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      order.isApproved ? 'Approvée' : 'En attente',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: order.isApproved ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(order.date),
                style: const TextStyle(color: Colors.grey),
              ),
              if (order.isApproved && order.approvedByName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Approuvée par: ${order.approvedByName}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    NumberFormat.currency(
                      symbol: 'DA ',
                      decimalDigits: 2,
                    ).format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, WidgetRef ref, OrderHistory order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(
          order: order,
          userId: userId,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final OrderHistory order;
  final String userId;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.userId,
  });

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  late List<OrderItem> currentItems;
  late OrderHistory currentOrder;

  @override
  void initState() {
    super.initState();
    currentItems = List.from(widget.order.items);
    currentOrder = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final total = currentItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final shortId = currentOrder.id.length > 8
        ? '${currentOrder.id.substring(0, 4)}...${currentOrder.id.substring(currentOrder.id.length - 4)}'
        : currentOrder.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #$shortId',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(currentOrder.date),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    currentOrder.isApproved
                        ? (currentOrder.approvedBy != null
                            ? 'Approvée par ${currentOrder.approvedBy}'
                            : 'Approvée avec ces modifications')
                        : 'en attente',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: currentOrder.isApproved ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: currentItems.length,
              itemBuilder: (context, index) => _buildOrderItem(
                context,
                ref,
                currentOrder,
                currentItems[index],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  NumberFormat.currency(
                    symbol: 'DA ',
                    decimalDigits: 2,
                  ).format(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(
    BuildContext context,
    WidgetRef ref,
    OrderHistory order,
    OrderItem item,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 40, 40, 40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${item.price.toStringAsFixed(2)} DA',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '×${item.quantity.toInt()}',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!order.isApproved)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: Colors.blue[600],
                    ),
                    onPressed: () => _showQuantityDialog(
                      context,
                      ref,
                      order.id,
                      item.id,
                      item.quantity,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Colors.red[600],
                    ),
                    onPressed: () => _showDeleteConfirmation(
                      context,
                      ref,
                      order.id,
                      item.id,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
    double currentQuantity,
  ) {
    final quantityController = TextEditingController(
      text: currentQuantity.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modify Quantity'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newQuantity = double.tryParse(quantityController.text) ?? currentQuantity;
              if (newQuantity > 0) {
                await _updateQuantity(
                  context,
                  ref,
                  orderId,
                  itemId,
                  newQuantity,
                );
                Navigator.pop(context); // Close the dialog
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity must be greater than 0')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
    double newQuantity,
  ) async {
    try {
      final params = OrderParams(orderId: orderId, userId: widget.userId);
      final notifier = ref.read(orderModificationProvider(params).notifier);
      await notifier.updateItemQuantity(itemId, newQuantity);
      await notifier.recalculateOrderTotal();

      // Update local state
      setState(() {
        currentItems = currentItems.map((item) {
          if (item.id == itemId) {
            return OrderItem(
              id: item.id,
              name: item.name,
              price: item.price,
              quantity: newQuantity,
            );
          }
          return item;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String orderId,
    String itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item from your order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final params = OrderParams(orderId: orderId, userId: widget.userId);
        final notifier = ref.read(orderModificationProvider(params).notifier);
        await notifier.removeItem(itemId);
        await notifier.recalculateOrderTotal();

        // Update local state
        setState(() {
          currentItems = currentItems.where((item) => item.id != itemId).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        return false;
      }
    }
    return false;
  }
}