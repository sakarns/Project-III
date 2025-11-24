import 'package:flutter/material.dart';
import '../shop/product_service.dart';
import '../shop/info_product_page.dart';
import 'favorite_controller.dart';
import 'cart_controller.dart';

class ProductController {
  final ProductService productService = ProductService();
  final FavoriteController favoriteController = FavoriteController();
  final CartController cartController = CartController();

  ProductController();

  Widget buildProductTile(
    Map<String, dynamic> product,
    ColorScheme colors,
    BuildContext context, {
    VoidCallback? onUpdate,
  }) {
    final productId = product['id'] as int;
    final inStock = product['in_stock'] ?? true;
    final unit = product['unit'] ?? '';
    final name = product['name'] ?? 'Item';
    final imageUrl = product['signed_image_url'] ?? '';
    final unitPrice = productService.formatNumber(product['price_per_unit']);
    final sellingPrice = productService.formatNumber(product['selling_price']);
    final quantity = (product['quantity'] ?? 0).toInt();

    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InfoProductPage(product: product),
              ),
            ).then((_) => onUpdate?.call()),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 140,
                    )
                  : Container(
                      height: 140,
                      color: colors.surface,
                      child: Icon(
                        Icons.shopping_bag,
                        size: 60,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          Text(
            "Price/$unit: Rs.$unitPrice",
            style: TextStyle(fontSize: 14, color: colors.primary),
          ),
          Text(
            "Price/$quantity $unit: Rs.$sellingPrice",
            style: TextStyle(fontSize: 14, color: colors.primary),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inStock ? "In Stock" : "Out of Stock",
                style: TextStyle(
                  color: inStock ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  favoriteController.favoriteIcon(productId, context, onUpdate),
                  const SizedBox(width: 12),
                  cartController.cartIcon(
                    productId: productId,
                    inStock: inStock,
                    quantity: quantity,
                    colors: colors,
                    context: context,
                    onUpdate: onUpdate,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProductList(
    List<Map<String, dynamic>> products,
    ColorScheme colors,
    BuildContext context, {
    VoidCallback? onUpdate,
  }) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.isEmpty ? 3 : products.length,
        itemBuilder: (context, index) {
          if (products.isEmpty) return _placeholder(colors);
          final product = products[index];
          return buildProductTile(product, colors, context, onUpdate: onUpdate);
        },
      ),
    );
  }

  Widget buildProductGrid(
    List<Map<String, dynamic>> products,
    ColorScheme colors,
    BuildContext context, {
    VoidCallback? onUpdate,
  }) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: products.isEmpty ? 3 : products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.60,
        mainAxisSpacing: 12,
        crossAxisSpacing: 0,
      ),
      itemBuilder: (context, index) {
        if (products.isEmpty) return _placeholder(colors);
        final product = products[index];
        return buildProductTile(product, colors, context, onUpdate: onUpdate);
      },
    );
  }

  Widget _placeholder(ColorScheme colors) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag,
          size: 60,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
