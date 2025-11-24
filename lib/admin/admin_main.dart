import 'package:flutter/material.dart';
import 'view_category_page.dart';
import 'view_product_page.dart';
import 'view_admins_page.dart';
import 'view_users_page.dart';
import 'view_orders_page.dart';
import 'view_checkouts_page.dart';
import 'view_delivery_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildCard(
              context,
              'Categories',
              Icons.grid_view,
              const ViewCategoryPage(),
            ),
            _buildCard(
              context,
              'Products',
              Icons.shopping_bag,
              const ViewProductPage(),
            ),
            _buildCard(
              context,
              'Admins',
              Icons.people_alt,
              const ViewAdminsPage(),
            ),
            _buildCard(context, 'Users', Icons.people, const ViewUsersPage()),
            _buildCard(
              context,
              'Orders',
              Icons.receipt_long,
              const ViewOrdersPage(),
            ),
            _buildCard(
              context,
              'Checkouts',
              Icons.checklist,
              const ViewCheckoutsPage(userId: '',),
            ),
            _buildCard(
              context,
              'Delivery',
              Icons.delivery_dining,
              const ViewDeliveryPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
  ) {
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50, color: Colors.blueAccent),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
