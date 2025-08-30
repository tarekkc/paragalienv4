import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/commande.dart';
import 'package:paragalien/models/profile.dart';
import 'package:paragalien/models/produit.dart';
import 'package:paragalien/providers/commande_provider.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCreateOrderPage extends ConsumerStatefulWidget {
  const AdminCreateOrderPage({super.key});

  @override
  ConsumerState<AdminCreateOrderPage> createState() =>
      _AdminCreateOrderPageState();
}

class _AdminCreateOrderPageState extends ConsumerState<AdminCreateOrderPage> {
  Profile? _selectedClient;
  final List<SelectedProduct> _selectedProducts = [];
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _clientSearchController.dispose();
    _productSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    return _selectedProducts.fold(
      0.0,
      (sum, item) => sum + (item.produit.price * item.quantity),
    );
  }

  int get _totalItems {
    return _selectedProducts.fold(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedClient == null) {
      _showSnackBar('Veuillez sélectionner un client', isError: true);
      return;
    }

    if (_selectedProducts.isEmpty) {
      _showSnackBar('Veuillez ajouter au moins un produit', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notes = _notesController.text.trim();
      await ref.read(commandeNotifierProvider).submitOrderWithNotes(
        _selectedProducts,
        _selectedClient!.id,
        notes.isNotEmpty ? notes : null,
      );

      if (mounted) {
        _showSnackBar('Commande créée avec succès!');
        
        // Clear the form
        setState(() {
          _selectedClient = null;
          _selectedProducts.clear();
          _notesController.clear();
        });

        // Refresh orders list
        ref.invalidate(allCommandesProvider);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur lors de la création: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showClientSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          title: const Text('Sélectionner un client'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    return TextField(
                      decoration: const InputDecoration(
                        labelText: 'Rechercher des clients',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return FutureBuilder<List<Profile>>(
                        future: _fetchClients(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text('Erreur: ${snapshot.error}'));
                          }

                          final clients = snapshot.data ?? [];
                          final filteredClients = clients.where((client) {
                            final query = searchQuery.toLowerCase();
                            return client.email.toLowerCase().contains(query) ||
                                (client.name?.toLowerCase().contains(query) ?? false);
                          }).toList();

                          if (filteredClients.isEmpty) {
                            return const Center(child: Text('Aucun client trouvé'));
                          }

                          return ListView.builder(
                            itemCount: filteredClients.length,
                            itemBuilder: (context, index) {
                              final client = filteredClients[index];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(client.name ?? client.email),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(client.email),
                                    if (client.locations.isNotEmpty)
                                      Text(
                                        'Région: ${client.locations.join(', ')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: _selectedClient?.id == client.id
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedClient = client;
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Profile>> _fetchClients() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'client')
          .order('name', ascending: true);

      return (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur lors du chargement des clients: $e');
      return [];
    }
  }

  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return AlertDialog(
          title: const Text('Ajouter des produits'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 400,
            child: Column(
              children: [
                StatefulBuilder(
                  builder: (context, setState) {
                    return TextField(
                      decoration: const InputDecoration(
                        labelText: 'Rechercher des produits',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return Consumer(
                        builder: (context, ref, child) {
                          final productsAsync = ref.watch(produitsProvider);
                          return productsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(child: Text('Erreur: $error')),
                            data: (products) {
                              final filteredProducts = products.where((product) {
                                final query = searchQuery.toLowerCase();
                                return product.name.toLowerCase().contains(query);
                              }).toList();

                              if (filteredProducts.isEmpty) {
                                return const Center(child: Text('Aucun produit trouvé'));
                              }

                              return ListView.builder(
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  final isAlreadyAdded = _selectedProducts
                                      .any((sp) => sp.produit.id == product.id);

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: product.imageUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                product.imageUrl!,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.shopping_bag),
                                              ),
                                            )
                                          : const Icon(Icons.shopping_bag),
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${product.price.toStringAsFixed(2)} DZD'),
                                          Text(
                                            'Stock: ${product.quantity.toInt()}',
                                            style: TextStyle(
                                              color: product.quantity > 0 
                                                  ? Colors.green 
                                                  : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: isAlreadyAdded
                                          ? const Icon(Icons.check, color: Colors.green)
                                          : const Icon(Icons.add),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _showQuantityDialog(product);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showQuantityDialog(Produit product) {
    final existingProduct = _selectedProducts
        .where((sp) => sp.produit.id == product.id)
        .firstOrNull;
    
    final TextEditingController quantityController = TextEditingController(
      text: existingProduct?.quantity.toInt().toString() ?? '1',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quantité pour ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: const OutlineInputBorder(),
                  helperText: 'Stock disponible: ${product.quantity.toInt()}',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              Text(
                'Prix unitaire: ${product.price.toStringAsFixed(2)} DZD',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                if (quantity > 0 && quantity <= product.quantity) {
                  _addOrUpdateProduct(product, quantity.toDouble());
                  Navigator.pop(context);
                } else {
                  _showSnackBar(
                    'Quantité invalide (1-${product.quantity.toInt()})',
                    isError: true,
                  );
                }
              },
              child: Text(existingProduct != null ? 'Mettre à jour' : 'Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _addOrUpdateProduct(Produit product, double quantity) {
    setState(() {
      final existingIndex = _selectedProducts
          .indexWhere((sp) => sp.produit.id == product.id);
      
      if (existingIndex >= 0) {
        _selectedProducts[existingIndex] = SelectedProduct(product, quantity);
      } else {
        _selectedProducts.add(SelectedProduct(product, quantity));
      }
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  void _updateProductQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) {
      _removeProduct(index);
      return;
    }

    setState(() {
      final product = _selectedProducts[index];
      _selectedProducts[index] = SelectedProduct(product.produit, newQuantity);
    });
  }

  void _showEditQuantityDialog(int index) {
    final product = _selectedProducts[index];
    final TextEditingController controller = TextEditingController(
      text: product.quantity.toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier ${product.produit.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Nouvelle quantité',
                  border: const OutlineInputBorder(),
                  helperText: 'Stock disponible: ${product.produit.quantity.toInt()}',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              Text(
                'Quantité actuelle: ${product.quantity.toInt()}',
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
              onPressed: () {
                final newQuantity = int.tryParse(controller.text) ?? 0;
                if (newQuantity > 0 && newQuantity <= product.produit.quantity) {
                  _updateProductQuantity(index, newQuantity.toDouble());
                  Navigator.pop(context);
                } else {
                  _showSnackBar(
                    'Quantité invalide (1-${product.produit.quantity.toInt()})',
                    isError: true,
                  );
                }
              },
              child: const Text('Mettre à jour'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Créer une commande'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.person_add, size: 28),
              onPressed: _showClientSelectionDialog,
              tooltip: 'Sélectionner un client',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_shopping_cart, size: 28),
              onPressed: _showProductSelectionDialog,
              tooltip: 'Ajouter des produits',
            ),
          ],
        ),
        actions: [
          if (_selectedProducts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _selectedProducts.clear();
                  _notesController.clear();
                });
              },
              tooltip: 'Vider le panier',
            ),
        ],
      ),
      body: Column(
        children: [
          // Notes Section (moved to top)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes pour la commande (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ),

          // Selected Client Info (compact)
          if (_selectedClient != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text('Client: ${_selectedClient!.name ?? _selectedClient!.email}'),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Selected Products List
          if (_selectedProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Produits sélectionnés ($_totalItems)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_totalPrice.toStringAsFixed(2)} DZD',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _selectedProducts.length,
                itemBuilder: (context, index) {
                  final item = _selectedProducts[index];
                  final totalItemPrice = item.produit.price * item.quantity;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Product Image
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: item.produit.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item.produit.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.shopping_bag),
                                        ),
                                      )
                                    : const Icon(Icons.shopping_bag),
                              ),
                              const SizedBox(width: 12),

                              // Product Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.produit.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.produit.price.toStringAsFixed(2)} DZD/unité',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Stock: ${item.produit.quantity.toInt()}',
                                      style: TextStyle(
                                        color: item.produit.quantity > 0 
                                            ? Colors.green 
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quantity and Actions
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '×${item.quantity.toInt()}',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _showEditQuantityDialog(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () => _removeProduct(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total pour ce produit:',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                '${totalItemPrice.toStringAsFixed(2)} DZD',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucun produit sélectionné',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Commencez par sélectionner un client et ajouter des produits',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Submit Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Création en cours...'),
                        ],
                      )
                    : Text(
                        _selectedProducts.isEmpty
                            ? 'Ajouter des produits pour continuer'
                            : 'Créer la commande (${_totalPrice.toStringAsFixed(2)} DZD)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}