import 'package:flutter/material.dart';
import 'package:paragalien/models/commande_item.dart';

class OrderTile extends StatelessWidget {
  final CommandeItem item;
  final VoidCallback? onRemove;

  const OrderTile({
    super.key,
    required this.item,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: onRemove != null
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: onRemove,
            )
          : null,
      title: Text(item.produit.name),
      subtitle: Text('${item.quantity}x • ${item.produit.price} € each'),
      trailing: Text(
        '${(item.produit.price * item.quantity).toStringAsFixed(2)} €',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}