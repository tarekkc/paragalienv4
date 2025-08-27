import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/produit.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'package:paragalien/views/client/commande_tab.dart';
import 'package:paragalien/views/client/profile_tab.dart';
import 'package:paragalien/views/client/paragalian_tab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:intl/intl.dart';

enum ClientTab { produits, commande, profile, paragalian }

class ClientHome extends ConsumerStatefulWidget {
  const ClientHome({super.key});

  @override
  ConsumerState<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends ConsumerState<ClientHome> {
  ClientTab _currentTab = ClientTab.produits;
  String _searchQuery = '';
  User? _currentUser;
  bool _showSearchBar = false;
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription<AuthState>? _authSubscription;

  final List<String> categories = [
    'Tous les produits',
    'Produits disponibles',
    'Produits en rupture',
    'Complément alimentaire',
    'Article bébé',
    'matériale médicale',
    'antiseptique',
    'dermo cosmetique',
  ];
  String selectedCategory = 'Produits disponibles';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      setState(() {
        _currentUser = event.session?.user;
      });
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  String formatPrice(double price) {
    if (price % 1 == 0) {
      return price.toStringAsFixed(0);
    } else {
      return price.toStringAsFixed(3);
    }
  }

  bool _matchesSearchQuery(Produit produit, String query) {
    if (query.isEmpty) return true;
    final productName = produit.name.toLowerCase();
    final searchTerms = query.toLowerCase().split(' ');
    return searchTerms.every((term) => productName.contains(term));
  }

  Future<void> _refreshData() async {
    try {
      await ref.refresh(produitsProvider.future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de rafraîchissement: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 63, 63, 63),
      appBar: AppBar(
        title:
            _currentTab == ClientTab.produits
                ? _showSearchBar
                    ? TextField(
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showSearchBar = false;
                              _searchQuery = '';
                            });
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 45,
                          width: 45,
                          child: Image.asset(
                            'assets/icons/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('ParaGalien'),
                      ],
                    )
                : const Text('ParaGalien'),
        actions: [
          if (_currentTab == ClientTab.produits && !_showSearchBar)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearchBar = true;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_currentTab == ClientTab.produits)
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF673AB7),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color.fromARGB(255, 44, 37, 53),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    iconSize: 24,
                    elevation: 16,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    underline: Container(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue!;
                        _searchQuery = '';
                      });
                    },
                    items:
                        categories.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab.index,
        onTap: (index) => setState(() => _currentTab = ClientTab.values[index]),
        selectedItemColor: const Color(0xFF673AB7),
        unselectedItemColor: const Color.fromARGB(255, 117, 73, 184),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Produits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Commande',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.diamond),
            label: 'ParaGalien',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case ClientTab.produits:
        return _buildProductsList(ref);
      case ClientTab.commande:
        if (_currentUser == null) {
          return const Center(
            child: Text('Veuillez vous connecter pour passer une commande'),
          );
        }
        return CommandeTab(userId: _currentUser!.id);
      case ClientTab.profile:
        return const ProfileTab();
      case ClientTab.paragalian:
        return const ParagalianPage();
    }
  }

 Widget _buildProductsList(WidgetRef ref) {
    final produitsAsync = ref.watch(produitsProvider);
    final selectedProduits = ref.watch(selectedProduitsProvider);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: produitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur: $error')),
        data: (produits) {
          List<Produit> filteredProduits =
              produits.where((p) {
                if (!_matchesSearchQuery(p, _searchQuery)) {
                  return false;
                }

                switch (selectedCategory) {
                  case 'Tous les produits':
                    return true;
                  case 'Produits disponibles':
                    return p.quantity > 0;
                  case 'Produits en rupture':
                    return p.quantity <= 0;
                  default:
                    return p.category == selectedCategory;
                }
              }).toList();

          if (selectedCategory == 'Produits en rupture') {
            filteredProduits.sort((a, b) => a.quantity.compareTo(b.quantity));
          }

          if (filteredProduits.isEmpty) {
            return ListView(
              children: [
                Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Aucun produit trouvé pour "$_searchQuery"'
                        : selectedCategory == 'Produits en rupture'
                        ? 'Aucun produit en rupture de stock'
                        : selectedCategory == 'Produits disponibles'
                        ? 'Aucun produit disponible'
                        : 'Aucun produit dans cette catégorie',
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredProduits.length,
            itemBuilder: (context, index) {
              final produit = filteredProduits[index];
              final quantity =
                  selectedProduits
                      .firstWhere(
                        (sp) => sp.produit.id == produit.id,
                        orElse: () => SelectedProduct(produit, 0),
                      )
                      .quantity;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          produit.imageUrl != null
                              ? GestureDetector(
                                  onTap: () => _showEnlargedImage(context, produit.imageUrl!),
                                  child: CachedNetworkImage(
                                    imageUrl: produit.imageUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                )
                              : const Icon(Icons.image, size: 80),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  produit.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatPrice(produit.price)} DA',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PPA: ${produit.ppa}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            produit.quantity > 0
                                ? 'En stock'
                                : 'Rupture de stock',
                            style: TextStyle(
                              color: produit.quantity > 0
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          if (produit.dateexp != null)
                            Text(
                              'Exp: ${DateFormat('dd/MM/yyyy').format(produit.dateexp!)}',
                              style: const TextStyle(color: Colors.orange),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showQuantityDialog(produit),
                          child: Text(
                            produit.quantity > 0
                                ? 'Ajouter au panier'
                                : 'Commander (rupture)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEnlargedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(imageUrl),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuantityDialog(Produit produit) {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool orderByPack = produit.packSize > 1;
    bool usePack = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Commander ${produit.name}'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (orderByPack) ...[
                      Row(
                        children: [
                          const Text('Commander par pack:'),
                          Switch(
                            value: usePack,
                            onChanged:
                                (value) => setState(() => usePack = value),
                          ),
                        ],
                      ),
                      if (usePack)
                        Text(
                          '1 pack = ${produit.packSize} unités (${(produit.price * produit.packSize).toStringAsFixed(2)} DA)',
                        ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: usePack ? 'Nombre de packs' : 'Quantité',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une quantité';
                        }
                        final quantity = double.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Quantité invalide';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      double quantity = double.parse(quantityController.text);
                      if (usePack) {
                        quantity *= produit.packSize;
                      }
                      ref
                          .read(selectedProduitsProvider.notifier)
                          .add(produit, quantity);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${quantity.toStringAsFixed(0)} unités ajoutées',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
