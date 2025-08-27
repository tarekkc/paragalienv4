import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/views/admin/orders_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/views/admin/products_mangment.dart';
import 'package:paragalien/views/admin/manage_users.dart';
import 'package:paragalien/views/admin/top_products_screen.dart'; 
import 'package:paragalien/views/admin/admin_orders.dart'; 

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _selectedIndex = 0;

  // Screens for each tab
  final List<Widget> _adminScreens = [
    const OrdersScreen(),
    const AdminUsersScreen(),
    const ProductsManagementScreen(),
    const TopProductsScreen(),
    const AdminCreateOrderPage(), // New screen for Top 5 products
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: _adminScreens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Commandes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Utilisateurs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Produits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Top 5',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Ajouter unecommande',
          ),
        ],
      ),
    );
  }
}