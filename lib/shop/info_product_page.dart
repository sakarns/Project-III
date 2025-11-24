import 'package:flutter/material.dart';
import '../core/cart_controller.dart';
import '../core/favorite_controller.dart';
import '../core/product_controller.dart';
import '../shop/product_session.dart';
import 'add_to_cart_page.dart';
import 'my_favorite_page.dart';
import '../core/recom_controller.dart';

class InfoProductPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const InfoProductPage({super.key, required this.product});

  @override
  State<InfoProductPage> createState() => _InfoProductPageState();
}

class _InfoProductPageState extends State<InfoProductPage> {
  final ProductController productController = ProductController();
  final CartController cartController = CartController();
  final FavoriteController favoriteController = FavoriteController();
  final RecomController recomController = RecomController();

  late Map<String, dynamic> product;
  List<Map<String, dynamic>> recommendedProducts = [];

  @override
  void initState() {
    super.initState();
    product = widget.product;
    _loadFavorite();
    _loadRecommendations();
  }

  Future<void> _loadFavorite() async {
    await productController.favoriteController.loadFavorites();
    if (mounted) setState(() {});
  }

  Future<void> _loadRecommendations() async {
    await recomController.loadRecommendations(topN: 8);
    final recoms = recomController.recommended;
    if (recoms.isEmpty) {
      final allProducts = List<Map<String, dynamic>>.from(ProductSession.products);
      allProducts.shuffle();
      recommendedProducts = allProducts.take(3).toList();
    } else {
      recommendedProducts = recoms;
    }
    if (mounted) setState(() {});
  }

  String formatPrice(dynamic price) {
    if (price is num) return price % 1 == 0 ? price.toInt().toString() : price.toString();
    return price.toString();
  }

  Widget _buildMainProduct(ColorScheme colors) {
    final productId = product['id'];
    final name = product['name'] ?? '';
    final imageUrl = product['signed_image_url'] ?? '';
    final unit = product['unit'] ?? '';
    final unitPrice = formatPrice(product['price_per_unit'] ?? 0);
    final sellingPrice = formatPrice(product['selling_price'] ?? 0);
    final quantity = (product['quantity'] ?? 1).toInt();
    final inStock = product['in_stock'] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isNotEmpty
              ? Image.network(
            imageUrl,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          )
              : Container(
            height: 180,
            color: colors.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.shopping_bag,
                size: 60,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
            productController.favoriteController.favoriteIcon(
              productId,
              context,
                  () => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Price/$unit: Rs.$unitPrice",
          style: TextStyle(fontSize: 16, color: colors.primary),
        ),
        Text(
          "Price/$quantity $unit: Rs.$sellingPrice",
          style: TextStyle(fontSize: 16, color: colors.primary),
        ),
        const SizedBox(height: 6),
        Text(
          inStock ? "In Stock" : "Out of Stock",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: inStock ? Colors.green : colors.error,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: inStock ? colors.primary : colors.surfaceContainerHighest,
              foregroundColor: inStock ? colors.onPrimary : colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: inStock
                ? () async {
              cartController.cartIcon(
                productId: productId,
                quantity: quantity,
                inStock: inStock,
                colors: colors,
                context: context,
                onUpdate: () => setState(() {}),
              );
            }
                : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text("Add to Cart"),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(ColorScheme colors) {
    final description = product['description'] ?? '';
    if (description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          "Description",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 16,
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedProducts(ColorScheme colors) {
    final categoryId = product['category_id'];
    final relatedProducts = ProductSession.products
        .where(
          (p) => p['category_id'] == categoryId && p['id'] != product['id'],
    )
        .toList();

    if (relatedProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          "Similar Products",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        productController.buildProductList(
          relatedProducts,
          colors,
          context,
          onUpdate: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildRecommendationSection(ColorScheme colors) {
    if (recommendedProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          "Recommended For You",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        productController.buildProductList(
          recommendedProducts,
          colors,
          context,
          onUpdate: () => setState(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddToCartPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyFavoritePage()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainProduct(colors),
            _buildDescription(colors),
            _buildRelatedProducts(colors),
            _buildRecommendationSection(colors),
          ],
        ),
      ),
    );
  }
}
