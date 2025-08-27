import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/models/produit.dart';

class PromotionsManagementScreen extends ConsumerStatefulWidget {
  const PromotionsManagementScreen({super.key});

  @override
  ConsumerState<PromotionsManagementScreen> createState() =>
      _PromotionsManagementScreenState();
}

class _PromotionsManagementScreenState
    extends ConsumerState<PromotionsManagementScreen> {
  final _searchController = TextEditingController();
  List<Produit> _promotedProduits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromotedProducts();
    _searchController.addListener(_filterProduits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPromotedProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('produits')
          .select('''
            *,
            promotions (
              is_active
            )
          ''')
          .order('name');

      setState(() {
        _promotedProduits =
            response
                .where((p) {
                  dynamic promotionsData = p['promotions'];
                  if (promotionsData is List) {
                    return promotionsData.isNotEmpty &&
                        promotionsData[0]['is_active'];
                  } else if (promotionsData is Map) {
                    return promotionsData['is_active'];
                  }
                  return false;
                })
                .map((p) => Produit.fromJson(p)..isInPromotion = true)
                .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: ${e.toString()}')),
        );
      }
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _promotedProduits =
          _promotedProduits.where((produit) {
            return produit.name.toLowerCase().contains(query) ||
                produit.price.toString().contains(query);
          }).toList();
    });
  }

  Future<void> _removeFromPromotion(Produit produit) async {
  try {
    final promotionResponse = await Supabase.instance.client
        .from('promotions')
        .select()
        .eq('id', produit.id)
        .maybeSingle();

    debugPrint('Response promotion: $promotionResponse');

    if (promotionResponse == null || promotionResponse['id'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucune promotion trouvée pour ${produit.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await Supabase.instance.client
        .from('promotions')
        .delete()
        .eq('id', promotionResponse['id']);

    await _loadPromotedProducts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${produit.name} retiré des promotions avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    debugPrint('Error removing promotion: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits en promotion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Rechercher',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une promotion...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterProduits();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _promotedProduits.isEmpty
                    ? const Center(child: Text('Aucun produit en promotion'))
                    : ListView.builder(
                      itemCount: _promotedProduits.length,
                      itemBuilder: (context, index) {
                        final produit = _promotedProduits[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading:
                                produit.imageUrl != null
                                    ? Image.network(
                                      produit.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                    : const Icon(Icons.shopping_bag),
                            title: Text(produit.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Prix: ${produit.price} DZD'),
                                const Text(
                                  'En promotion',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'remove_promotion') {
                                  _removeFromPromotion(produit);
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  const PopupMenuItem<String>(
                                    value: 'remove_promotion',
                                    child: Text(
                                      'Retirer des promotions',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
