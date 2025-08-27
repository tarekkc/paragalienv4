import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:paragalien/views/admin/promotions_management_screen.dart';
import 'package:paragalien/models/produit.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProductsManagementScreen extends ConsumerStatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  ConsumerState<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState
    extends ConsumerState<ProductsManagementScreen> {
  final _searchController = TextEditingController();
  List<Produit> _allProduits = [];
  List<Produit> _filteredProduits = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProduits();
    _searchController.addListener(_filterProduits);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('produits')
          .select('*')
          .order('name');

      setState(() {
        _allProduits = response.map((p) => Produit.fromJson(p)).toList();
        _filterProduits(); // Apply current filter to new data
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur de chargement: ${e.toString()}');
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredProduits = List.from(_allProduits);
      });
      return;
    }

    setState(() {
      _filteredProduits =
          _allProduits.where((produit) {
            final name = produit.name.toLowerCase();
            final price = produit.price.toString();
            final quantity = produit.quantity.toString();
            final category = produit.category?.toLowerCase() ?? '';

            // Basic direct matching
            if (name.contains(query) ||
                price.contains(query) ||
                quantity.contains(query) ||
                category.contains(query)) {
              return true;
            }

            // Fuzzy search implementation
            final queryWords = query.split(' ');
            final nameWords = name.split(' ');

            // Check if all query words are present in any order
            bool allWordsMatch = queryWords.every(
              (qWord) =>
                  nameWords.any((nWord) => nWord.startsWith(qWord)) ||
                  queryWords.every(
                    (qWord) =>
                        nameWords.any((nWord) => nWord.contains(qWord)) ||
                        name.contains(query.replaceAll(' ', '')),
                  ),
            );

            // Check for acronym match (like "sol mag" matching "solyne magnesium")
            bool acronymMatch = false;
            if (queryWords.length > 1) {
              final productAcronym =
                  nameWords
                      .map((word) => word.isNotEmpty ? word[0] : '')
                      .join();
              acronymMatch = productAcronym.contains(query.replaceAll(' ', ''));
            }

            return allWordsMatch || acronymMatch;
          }).toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Produits'),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_offer),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PromotionsManagementScreen(),
                  ),
                );
              },
              tooltip: 'Voir les promotions',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showEditProductDialog(context),
              tooltip: 'Ajouter un produit',
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
                  hintText: 'Rechercher un produit...',
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
                      : _filteredProduits.isEmpty
                      ? Center(
                        child:
                            _searchController.text.isEmpty
                                ? const Text('Aucun produit trouvé')
                                : const Text(
                                  'Aucun résultat pour cette recherche',
                                ),
                      )
                      : ListView.builder(
                        itemCount: _filteredProduits.length,
                        itemBuilder: (context, index) {
                          final produit = _filteredProduits[index];
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
                                  Text('Stock: ${produit.quantity}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  // Make this async
                                  if (value == 'edit') {
                                    await _showEditProductDialog(
                                      context,
                                      produit,
                                    ); // Wait for edit to complete
                                    _filterProduits(); // Re-apply the filter
                                  } else if (value == 'delete') {
                                    _showDeleteConfirmation(context, produit);
                                  } else if (value == 'promotion') {
                                    _showAddToPromotionDialog(context, produit);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return [
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text('Modifier'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'promotion',
                                      child: Text('Ajouter au promotion'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(
                                        'Supprimer',
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
      ),
    );
  }

  Future<void> _showEditProductDialog(
    BuildContext context, [
    Produit? produit,
  ]) async {
    final nameController = TextEditingController(text: produit?.name ?? '');
    final currentSearchQuery = _searchController.text;
    final priceController = TextEditingController(
      text: produit?.price.toString() ?? '',
    );
    final ppaController = TextEditingController(
      text: produit?.ppa.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: produit?.quantity.toString() ?? '', // Using quantity getter
    );
    final datecontroller = TextEditingController(
      text:
          produit?.dateexp != null
              ? DateFormat('dd/MM/yyyy').format(produit!.dateexp!)
              : '',
    );
    String? imagePath;
    Uint8List? imageBytes;
    bool isUploading = false;
    String? selectedCategory = produit?.category;
    bool shouldDeleteImage = false;

    const List<String> categories = [
      'Complément alimentaire',
      'matériale médicale',
      'antiseptique',
      'dermo cosmetique',
      'Article bébé',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  produit == null ? 'Ajouter un produit' : 'Modifier produit',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        )
                      else if (imageBytes != null ||
                          (produit?.imageUrl != null && !shouldDeleteImage))
                        Column(
                          children: [
                            Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  imageBytes != null
                                      ? Image.memory(
                                        imageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                      : produit?.imageUrl != null
                                      ? Image.network(
                                        produit!.imageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Supprimer image'),
                                        content: const Text(
                                          'Voulez-vous vraiment supprimer cette image?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text(
                                              'Supprimer',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );

                                if (confirm == true) {
                                  setState(() {
                                    imageBytes = null;
                                    imagePath = null;
                                    shouldDeleteImage = true;
                                  });
                                }
                              },
                              child: const Text(
                                'Supprimer image',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Choisir une image'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: ['jpg', 'jpeg', 'png'],
                          );

                          if (result != null &&
                              result.files.single.path != null) {
                            final filePath = result.files.single.path!;

                            // Compress the image
                            setState(() => isUploading = true);
                            try {
                              final compressedBytes =
                                  await FlutterImageCompress.compressWithFile(
                                    filePath,
                                    minWidth: 100,
                                    minHeight: 100,
                                    quality: 90,
                                  );

                              if (compressedBytes == null) {
                                throw Exception('Compression failed');
                              }

                              const maxSizeInBytes = 60 * 1024; // 60 KB

                              Uint8List? compressedImage;
                              int quality = 95;
                              int minWidth = 300;
                              int minHeight = 300;

                              while (quality >= 30) {
                                final resultBytes =
                                    await FlutterImageCompress.compressWithFile(
                                      filePath,
                                      quality: quality,
                                      minWidth: minWidth,
                                      minHeight: minHeight,
                                    );

                                if (resultBytes != null &&
                                    resultBytes.length <= maxSizeInBytes) {
                                  compressedImage = resultBytes;
                                  break;
                                }

                                // Reduce quality or size for next attempt
                                quality -= 10;
                                minWidth = (minWidth * 0.9).round();
                                minHeight = (minHeight * 0.9).round();
                              }

                              if (compressedImage != null) {
                                setState(() {
                                  imagePath = filePath;
                                  imageBytes = compressedImage;
                                  shouldDeleteImage = false;
                                });
                              } else {
                                throw Exception(
                                  'Impossible de compresser l\'image sous 60 Ko',
                                );
                              }
                            } catch (e) {
                              _showSnackBar(
                                'Erreur de compression: ${e.toString()}',
                                isError: true,
                              );
                            } finally {
                              setState(() => isUploading = false);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Aucune catégorie'),
                          ),
                          ...categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du produit*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Prix (DZD)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: ppaController,
                        decoration: const InputDecoration(
                          labelText: 'PPA*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: datecontroller,
                        decoration: const InputDecoration(
                          labelText: 'DATE*',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true, // Prevent keyboard input
                        onTap: () async {
                          // Show date picker when tapped
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: produit?.dateexp ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            datecontroller.text = DateFormat(
                              'dd/MM/yyyy',
                            ).format(pickedDate);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          try {
                            DateFormat('dd/MM/yyyy').parse(value);
                            return null;
                          } catch (e) {
                            return 'Entrez une date valide (JJ/MM/AAAA)';
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantité en stock*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isUploading
                            ? null
                            : () async {
                              // Validate form (category is no longer required)
                              if (nameController.text.isEmpty ||
                                  priceController.text.isEmpty ||
                                  quantityController.text.isEmpty) {
                                _showSnackBar(
                                  'Veuillez remplir tous les champs obligatoires',
                                  isError: true,
                                );
                                return;
                              }

                              setState(() => isUploading = true);
                              String? imageUrl;

                              try {
                                // Handle image deletion if marked for deletion
                                if (shouldDeleteImage &&
                                    produit?.imageUrl != null) {
                                  try {
                                    final oldFileName =
                                        produit!.imageUrl!.split('/').last;
                                    await Supabase.instance.client.storage
                                        .from('paragalien.photos')
                                        .remove([oldFileName]);
                                  } catch (e) {
                                    debugPrint('Error deleting old image: $e');
                                  }
                                }

                                // Upload new image if selected
                                if (imageBytes != null) {
                                  if (produit?.imageUrl != null &&
                                      !shouldDeleteImage) {
                                    try {
                                      final oldFileName =
                                          produit!.imageUrl!.split('/').last;
                                      await Supabase.instance.client.storage
                                          .from('paragalien.photos')
                                          .remove([oldFileName]);
                                    } catch (e) {
                                      debugPrint(
                                        'Error deleting old image: $e',
                                      );
                                    }
                                  }

                                  final fileName =
                                      '${DateTime.now().millisecondsSinceEpoch}${path.extension(imagePath!)}';

                                  await Supabase.instance.client.storage
                                      .from('paragalien.photos')
                                      .uploadBinary(fileName, imageBytes!);

                                  imageUrl = Supabase.instance.client.storage
                                      .from('paragalien.photos')
                                      .getPublicUrl(fileName);
                                }

                                // Prepare product data
                                final newProduit = {
                                  'name': nameController.text.trim(),
                                  'price':
                                      double.tryParse(priceController.text) ??
                                      0,
                                  'stock_unite':
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      0,
                                  'image_url':
                                      shouldDeleteImage
                                          ? null
                                          : (imageUrl ?? produit?.imageUrl),
                                  'category': selectedCategory,
                                  'updated_at':
                                      DateTime.now().toIso8601String(),
                                };

                                if (produit == null) {
                                  await Supabase.instance.client
                                      .from('produits')
                                      .insert(newProduit);
                                } else {
                                  await Supabase.instance.client
                                      .from('produits')
                                      .update(newProduit)
                                      .eq('id', produit.id);
                                }

                                Navigator.pop(context, true);
                              } catch (e) {
                                debugPrint('Error saving product: $e');
                                _showSnackBar(
                                  'Erreur: ${e.toString()}',
                                  isError: true,
                                );
                                setState(() => isUploading = false);
                              }
                            },
                    child:
                        isUploading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
    );

    if (result == true && mounted) {
      await _loadProduits();
      _showSnackBar(
        produit == null ? 'Produit ajouté avec succès' : 'Produit mis à jour',
      );
      _searchController.text = currentSearchQuery;
      _filterProduits();
    }
  }

  Future<void> _showAddToPromotionDialog(
    BuildContext context,
    Produit produit,
  ) async {
    final newPriceController = TextEditingController(
      text: (produit.price * 0.9).toStringAsFixed(2), // Default to 10% off
    );
    final descriptionController = TextEditingController();
    DateTime? startDate = DateTime.now();
    DateTime? endDate = DateTime.now().add(const Duration(days: 7));
    bool isSaving = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Créer une promotion'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: newPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau prix (DZD)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ce champ est obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Entrez un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description de la promotion',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Date de début'),
                        subtitle: Text(
                          startDate != null
                              ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                              : 'Non sélectionné',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (pickedDate != null) {
                            setState(() => startDate = pickedDate);
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('Date de fin'),
                        subtitle: Text(
                          endDate != null
                              ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                              : 'Non sélectionné',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                endDate ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (pickedDate != null) {
                            setState(() => endDate = pickedDate);
                          }
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
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              if (newPriceController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Le prix est obligatoire'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() => isSaving = true);
                              try {
                                final newPrice =
                                    double.tryParse(newPriceController.text) ??
                                    0;

                                // Create promotion in database
                                await Supabase.instance.client
                                    .from('promotions')
                                    .insert({
                                      'product_id': produit.id,
                                      'original_price': produit.price,
                                      'promotion_price': newPrice,
                                      'description': descriptionController.text,
                                      'start_date':
                                          startDate?.toIso8601String(),
                                      'end_date': endDate?.toIso8601String(),
                                      'created_at':
                                          DateTime.now().toIso8601String(),
                                    });

                                Navigator.pop(context);
                                if (mounted) {
                                  _showSnackBar('Promotion créée avec succès');
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setState(() => isSaving = false);
                              }
                            },
                    child:
                        isSaving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Créer la promotion'),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Produit produit) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Supprimer ${produit.name}? Cette action est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await Supabase.instance.client
                        .from('produits')
                        .delete()
                        .eq('id', produit.id);

                    Navigator.pop(context);
                    await _loadProduits();
                    _showSnackBar('Produit supprimé avec succès');
                  } catch (e) {
                    Navigator.pop(context);
                    _showSnackBar('Erreur: ${e.toString()}', isError: true);
                  }
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}
