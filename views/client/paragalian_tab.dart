import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/produit.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'package:paragalien/providers/promotion_provider.dart';
import 'package:paragalien/providers/top_products_provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math';

class ParagalianPage extends ConsumerWidget {
  const ParagalianPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(promotionsProvider);
    final topProducts = ref.watch(topProductsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Top panel with violet background
          Container(
            height: 50,
            width: double.infinity,
            color: const Color.fromARGB(255, 37, 33, 45),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Produits en promotion: ',
                  style: TextStyle(
                    color: Color.fromARGB(255, 228, 237, 248),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.local_offer, color: Colors.yellow[200], size: 28),
              ],
            ),
          ),
          
          // Products grid and statistics
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Promotions Grid
                  promotionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Erreur: $error')),
                    data: (promotions) {
                      if (promotions.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aucun produit en promotion actuellement.',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: promotions.length,
                        itemBuilder: (context, index) {
                          final promotion = promotions[index];
                          final produit = promotion.product;

                          final discountPercentage =
                              ((promotion.originalPrice - promotion.promotionPrice) /
                                      promotion.originalPrice *
                                      100)
                                  .round();

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Promotion ribbon
                                Container(
                                  height: 24,
                                  color: Colors.red,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$discountPercentage% PROMOTION',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                // Product image
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(0),
                                    ),
                                    child: produit.imageUrl != null
                                        ? Image.network(
                                            produit.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.image_not_supported),
                                          )
                                        : const Icon(Icons.image, size: 50),
                                  ),
                                ),
                                // Product details
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        produit.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${promotion.promotionPrice.toStringAsFixed(2)} DA',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${promotion.originalPrice.toStringAsFixed(2)} DA',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              decoration: TextDecoration.lineThrough,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        produit.quantity > 0 ? 'Stock: disponible' : '',
                                        style: TextStyle(
                                          color: produit.quantity > 0
                                              ? Colors.green
                                              : Colors.transparent,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (promotion.description != null)
                                        Text(
                                          promotion.description!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color.fromARGB(
                                                  255,
                                                  128,
                                                  58,
                                                  240,
                                                ),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 8),
                                              ),
                                              onPressed: () {
                                                _showPromotionQuantityDialog(
                                                  context,
                                                  ref,
                                                  produit,
                                                  promotion.promotionPrice,
                                                );
                                              },
                                              child: const Text('Ajouter'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  
                  // Top 5 Products Section
                  Container(
                    margin: const EdgeInsets.only(top: 50, bottom: 20, right: 20, left: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 51, 51, 51),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 34, 19, 40).withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top 5 Produits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 201, 201, 201),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nos produits les plus populaires',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Large Pie Chart with equal segments
                        Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: CustomPaint(
                              painter: _TopProductsPieChartPainter(
                                products: _getDisplayedProducts(topProducts),
                              ),
                            ),
                          ),
                        ),
                        
                        // Legend
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          children: _getDisplayedProducts(topProducts).map((product) {
                            final displayText = product.productName.isNotEmpty
                                ? '${product.productId} - ${product.productName}'
                                : 'Position ${product.rank} (vide)';
                            return _buildLegendItem(
                              product.color,
                              displayText,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TopProduct> _getDisplayedProducts(List<TopProduct> topProducts) {
    return List<TopProduct>.generate(
      5,
      (index) => topProducts.firstWhere(
        (p) => p.rank == index + 1,
        orElse: () => TopProduct(
          id: -1,
          rank: index + 1,
          productId: '',
          productName: '',
          color: TopProduct.getColorByRank(index + 1),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showPromotionQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    Produit produit,
    double promotionPrice,
  ) {
    final TextEditingController quantityController = TextEditingController(text: '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: const Color.fromARGB(255, 58, 183, 104).withOpacity(0.8),
            contentPadding: EdgeInsets.zero,
            titlePadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 160, 137, 200),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Entrez la quantité',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          produit.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Prix promotionnel: ${promotionPrice.toStringAsFixed(2)} DA',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ancien prix: ${produit.price.toStringAsFixed(2)} DA',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (produit.dateexp != null)
                          Text(
                            'Date d\'expiration: ${DateFormat('dd/MM/yyyy').format(produit.dateexp!)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Quantité',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 191, 237, 192),
                              ),
                            ),
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          style: const TextStyle(
                            color: Color.fromARGB(255, 159, 196, 160),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer une quantité';
                            }
                            final quantity = double.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'La quantité doit être > 0';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 146, 131, 170),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final quantity = double.parse(quantityController.text);
                            ref.read(selectedProduitsProvider.notifier).add(produit, quantity);
                            Navigator.pop(context);
                            _showOrderConfirmation(
                              context,
                              produit,
                              quantity,
                              promotionPrice,
                            );
                          }
                        },
                        child: const Text(
                          'Confirmer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderConfirmation(
    BuildContext context,
    Produit produit,
    double quantity,
    double promotionPrice,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ajouté: ${produit.name} (x${quantity.toStringAsFixed(0)}) à ${promotionPrice.toStringAsFixed(2)} DA',
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}

class _TopProductsPieChartPainter extends CustomPainter {
  final List<TopProduct> products;

  _TopProductsPieChartPainter({
    required this.products,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
    
    const double segmentAngle = 2 * pi / 5;
    double startAngle = -pi / 2;
    
    for (int i = 0; i < products.length; i++) {
      paint.color = products[i].color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );
      startAngle += segmentAngle;
    }
    
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}