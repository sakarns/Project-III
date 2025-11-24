import 'package:flutter/material.dart';
import '../core/product_controller.dart';
import 'product_session.dart';
import '../core/favorite_controller.dart';

class MyFavoritePage extends StatefulWidget {
  const MyFavoritePage({super.key});

  @override
  State<MyFavoritePage> createState() => _MyFavoritePageState();
}

class _MyFavoritePageState extends State<MyFavoritePage> {
  final ProductController productController = ProductController();
  final FavoriteController favoriteController = FavoriteController();
  List<Map<String, dynamic>> favProducts = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    await favoriteController.loadFavorites();
    await productController.favoriteController.loadFavorites();

    final favIds = favoriteController.favoriteIds;
    final allProducts = ProductSession.products;
    if (!mounted) return;
    setState(() {
      favProducts = allProducts.where((p) => favIds.contains(p['id'])).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        color: colors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: favProducts.isEmpty
              ? SizedBox(
                  height:
                      MediaQuery.of(context).size.height - kToolbarHeight - 24,
                  child: Center(
                    child: Text(
                      'No favorites yet',
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ),
                )
              : productController.buildProductGrid(
                  favProducts,
                  colors,
                  context,
                  onUpdate: _loadFavorites,
                ),
        ),
      ),
    );
  }
}
