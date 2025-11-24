import 'package:flutter/material.dart';
import '../shop/cart_service.dart';

class CartController {
  final CartService _cartService = CartService();
  final Map<int, bool> _processing = {};

  bool isProcessing(int productId) => _processing[productId] == true;

  void setProcessing(int productId, bool value) =>
      _processing[productId] = value;

  Widget cartIcon({
    required int productId,
    required int quantity,
    required bool inStock,
    required ColorScheme colors,
    required BuildContext context,
    VoidCallback? onUpdate,
  }) {
    final busy = isProcessing(productId);
    final disabled = busy || !inStock;

    return GestureDetector(
      onTap: disabled
          ? null
          : () async {
              setProcessing(productId, true);
              onUpdate?.call();

              await _cartService.handleAddToCart(context, productId, quantity);

              setProcessing(productId, false);
              onUpdate?.call();
            },
      child: Icon(
        Icons.add_shopping_cart,
        size: 24,
        color: disabled ? colors.onSurfaceVariant : colors.primary,
      ),
    );
  }
}
