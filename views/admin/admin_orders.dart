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
  final TextEditingController _productSearchController =
      TextEditingController();

  @override
  void dispose() {
    _clientSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    return _selectedProducts.fold(
      0.0,
      (sum, item) => sum + (item.produit.price * item.quantity),
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a client')));
      return;
    }

    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    try {
      await ref
          .read(commandeNotifierProvider)
          .submitOrder(_selectedProducts, _selectedClient!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating order: $e')));
    }
  }

  void _showClientSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Client'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _clientSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search clients',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<Profile>>(
                    future: _fetchClients(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final clients = snapshot.data ?? [];
                      final filteredClients =
                          clients.where((client) {
                            final query =
                                _clientSearchController.text.toLowerCase();
                            return client.email.toLowerCase().contains(query) ||
                                (client.name?.toLowerCase().contains(query) ??
                                    false);
                          }).toList();

                      if (filteredClients.isEmpty) {
                        return const Center(child: Text('No clients found'));
                      }

                      return ListView.builder(
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(client.name ?? client.email),
                            subtitle: Text(client.email),
                            trailing:
                                _selectedClient?.id == client.id
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    )
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
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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

      final clients =
          (response as List).map((json) => Profile.fromJson(json)).toList();

      return clients;
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      return []; // Return empty list on error
    }
  }

  void _showProductSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Products'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _productSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search products',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final productsAsync = ref.watch(produitsProvider);
                      return productsAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (error, stack) =>
                                Center(child: Text('Error: $error')),
                        data: (products) {
                          final filteredProducts =
                              products.where((product) {
                                final query =
                                    _productSearchController.text.toLowerCase();
                                return product.name.toLowerCase().contains(
                                  query,
                                );
                              }).toList();

                          if (filteredProducts.isEmpty) {
                            return const Center(
                              child: Text('No products found'),
                            );
                          }

                          return ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return ListTile(
                                leading: const Icon(Icons.shopping_bag),
                                title: Text(product.name),
                                subtitle: Text(
                                  '\$${product.price.toStringAsFixed(2)}',
                                ),
                                onTap: () {
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close the product selection dialog
                                  _showQuantityDialog(product);
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
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

 void _showQuantityDialog(Produit product) {
  final TextEditingController _quantityController = TextEditingController(text: '1');

  showDialog(
    context: context,
    builder: (context) {
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final totalPrice = product.price * quantity;

      return AlertDialog(
        title: Text('Select Quantity for ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                // Update the total price when quantity changes
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Price per unit: \$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Total: \$${totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(_quantityController.text) ?? 1;
              if (quantity > 0) {
                setState(() {
                  final existingIndex = _selectedProducts.indexWhere(
                    (sp) => sp.produit.id == product.id
                  );
                  
                  if (existingIndex >= 0) {
                    // Update existing product quantity
                    _selectedProducts[existingIndex] = SelectedProduct(
                      product,
                      _selectedProducts[existingIndex].quantity + quantity.toDouble(),
                    );
                  } else {
                    // Add new product
                    _selectedProducts.add(SelectedProduct(product, quantity.toDouble()));
                  }
                });
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity (1 or more)')),
                );
              }
            },
            child: const Text('Add to Order'),
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order (Admin)')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MODIFY THIS SECTION - change from Column to Row
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, size: 17),
                      title: Text(
                        _selectedClient == null
                            ? 'Select Client'
                            : 'Client: ${_selectedClient!.name ?? _selectedClient!.email}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: _showClientSelectionDialog,
                    ),
                  ),
                ),
                const SizedBox(width: 18), // Add horizontal spacing
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.shopping_bag, size: 17),
                      title: const Text(
                        'Add Products',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: _showProductSelectionDialog,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (_selectedProducts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedProducts.length,
                  itemBuilder: (context, index) {
                    final item = _selectedProducts[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.shopping_bag),
                        title: Text(item.produit.name),
                        subtitle: Text(
                          'Quantity: ${item.quantity} x \$${item.produit.price.toStringAsFixed(2)}',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Total: \$${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: Colors.green,
              ),
              child: const Text('Create Order', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
