import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/commande.dart';
import 'package:paragalien/models/commande_item.dart';
import 'package:paragalien/providers/commande_provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final Commande order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  late Commande _currentOrder;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${_currentOrder.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            onPressed: _showNotesDialog,
            tooltip: 'Ajouter des notes',
          ),
          if (!_currentOrder.isApproved)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: _approveOrder,
              tooltip: 'Approuver la commande',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildOrderHeader(),
          _buildOrderNotes(),
          Expanded(child: _buildProductList()),
          _buildOrderFooter(),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                backgroundColor:
                    _currentOrder.isApproved
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                label: Text(
                  _currentOrder.isApproved ? 'Approuvée' : 'En attente',
                  style: TextStyle(
                    color:
                        _currentOrder.isApproved ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                avatar: Icon(
                  _currentOrder.isApproved
                      ? Icons.check_circle
                      : Icons.access_time,
                  size: 18,
                  color:
                      _currentOrder.isApproved ? Colors.green : Colors.orange,
                ),
              ),
              Text(
                _dateFormat.format(_currentOrder.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Client: ${_currentOrder.userProfile?.name ?? _currentOrder.userId}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNotes() {
    if (_currentOrder.clientNotes == null ||
        _currentOrder.clientNotes!.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, size: 18, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentOrder.clientNotes!,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _currentOrder.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _currentOrder.items[index];
        return _buildProductCard(item, index);
      },
    );
  }

  Widget _buildProductCard(CommandeItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 37, 37, 37),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First Row: Image and Product Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color.fromARGB(255, 115, 115, 115),
                        image: item.produit.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(item.produit.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item.produit.imageUrl == null
                          ? const Icon(
                              Icons.shopping_bag,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Product Name and Total Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.produit.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Second Row: Unit Price, Quantity and Action Buttons
                Padding(
                  padding: const EdgeInsets.only(left: 72), // Align with product name
                  child: Row(
                    children: [
                      // Unit Price and Quantity
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Text(
                              '${item.produit.price.toStringAsFixed(2)} DZD/unité',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _currentOrder.isApproved
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '×${item.quantity.toInt()}',
                                style: TextStyle(
                                  color: _currentOrder.isApproved
                                      ? Colors.green.shade800
                                      : Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons - Only show if order is not approved
                      if (!_currentOrder.isApproved)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.blue.shade600,
                              ),
                              onPressed: () => _showQuantityDialog(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                              onPressed: () => _removeItem(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stock Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 67, 67, 67),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Stock disponible: ${item.produit.quantity.toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total:',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_calculateTotal().toStringAsFixed(2)} DZD',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color.fromARGB(255, 0, 118, 10),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotesDialog() async {
    _notesController.text = _currentOrder.clientNotes ?? '';

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notes pour la commande'),
            content: TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Tapez vos notes ici...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: _updateOrderNotes,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  Future<void> _showQuantityDialog(int index) async {
    final item = _currentOrder.items[index];
    final controller = TextEditingController(
      text: item.quantity.toInt().toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier quantité pour ${item.produit.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nouvelle quantité',
                  hintText: 'Stock disponible: ${item.produit.quantity}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Quantité actuelle: ${item.quantity.toInt()}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newQuantity =
                    int.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
                if (newQuantity > 0 && newQuantity <= item.produit.quantity) {
                  await _updateQuantityInDatabase(index, newQuantity);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Veuillez entrer une quantité valide (0-${item.produit.quantity})',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateQuantityInDatabase(int index, int newQuantity) async {
    try {
      final item = _currentOrder.items[index];

      // Update in Supabase
      await Supabase.instance.client
          .from('commande_items')
          .update({'quantity': newQuantity})
          .eq('id', item.id);

      // Update local state
      setState(() {
        _currentOrder.items[index] = item.copyWith(quantity: newQuantity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité mise à jour avec succès!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: ${e.toString()}'),
        ),
      );
    }
  }

  void _removeItem(int index) {
    if (_currentOrder.isApproved) return;

    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer le produit'),
            content: Text(
              'Voulez-vous vraiment supprimer ${_currentOrder.items[index].produit.name} de la commande?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context); // Close the dialog
                  await _removeItemFromDatabase(index);
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }

  Future<void> _removeItemFromDatabase(int index) async {
    try {
      final item = _currentOrder.items[index];

      // Delete from Supabase
      await Supabase.instance.client
          .from('commande_items')
          .delete()
          .eq('id', item.id);

      // Update local state
      setState(() {
        _currentOrder.items.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.produit.name} supprimé de la commande')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _updateOrderNotes() async {
    if (_notesController.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      await Supabase.instance.client
          .from('commandes')
          .update({
            'client_notes': _notesController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentOrder.id);

      if (mounted) {
        setState(() {
          _currentOrder = _currentOrder.copyWith(
            clientNotes: _notesController.text.trim(),
          );
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes mises à jour!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  double _calculateTotal() {
    return _currentOrder.items.fold(
      0.0,
      (sum, item) => sum + (item.produit.price * item.quantity),
    );
  }

  Future<void> _approveOrder() async {
    try {
      final shouldApprove = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Approuver la commande'),
              content: const Text(
                'Êtes-vous sûr de vouloir approuver cette commande?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Approuver'),
                ),
              ],
            ),
      );

      if (shouldApprove == true) {
        // Convert ID to integer explicitly
        final orderId =
            _currentOrder.id is double
                ? _currentOrder.id.toInt()
                : _currentOrder.id;

        await ref.read(commandeNotifierProvider).approveOrder(orderId);
        setState(() {
          _currentOrder = _currentOrder.copyWith(isApproved: true);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande approuvée avec succès!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
