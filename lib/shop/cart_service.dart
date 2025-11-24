import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/user_session.dart';

class CartService {
  final _supabase = Supabase.instance.client;
  final String _productBucket = 'product-images';

  // Load cart items, optionally filter only active items
  Future<List<Map<String, dynamic>>> getCartItems({
    bool onlyActive = true,
  }) async {
    final userId = UserSession.userId;
    if (userId == null) return [];

    var query = _supabase
        .from('cart')
        .select('*, products(*)')
        .eq('user_id', userId);
    if (onlyActive) query = query.eq('is_ordered', false);

    final response = await query;
    final List<Map<String, dynamic>> items = [];

    for (final raw in response) {
      final item = Map<String, dynamic>.from(raw);
      final product = Map<String, dynamic>.from(item['products'] ?? {});
      final imageUrl = (product['image_url'] ?? '').toString();

      if (imageUrl.isNotEmpty) {
        try {
          final imageName = imageUrl.split('/').last;
          final signedUrl = await _supabase.storage
              .from(_productBucket)
              .createSignedUrl('product_images/$imageName', 3600);
          product['signed_image_url'] = signedUrl;
        } catch (_) {
          product['signed_image_url'] = imageUrl;
        }
      }

      item['products'] = product;
      items.add(item);
    }

    return items;
  }

  // Check if product exists for user (ignore is_ordered)
  Future<bool> isProductInCart(int productId) async {
    final userId = UserSession.userId;
    if (userId == null) return false;

    final existing = await _supabase
        .from('cart')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    return existing != null;
  }

  // Add product to cart only if not already present
  Future<void> addToCart(int productId, int quantity) async {
    final userId = UserSession.userId;
    if (userId == null) throw Exception('User not logged in');

    final exists = await isProductInCart(productId);
    if (exists) throw Exception('Product already in cart');

    await _supabase.from('cart').insert({
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'is_ordered': false,
      'describe_requirements': 'Offered Quantity & Price',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFromCart(int cartId) async {
    await _supabase.from('cart').delete().eq('id', cartId);
  }

  Future<void> updateCartItem(
    int cartId,
    int quantity, {
    String? requirements,
    bool markOrdered = false,
  }) async {
    final data = {
      'quantity': quantity,
      'updated_at': DateTime.now().toIso8601String(),
      'is_ordered': markOrdered,
    };
    if (requirements != null && requirements.isNotEmpty) {
      data['describe_requirements'] = requirements;
    }

    await _supabase.from('cart').update(data).eq('id', cartId);
  }

  Future<void> handleAddToCart(
    BuildContext context,
    int productId,
    int quantity,
  ) async {
    try {
      final alreadyInCart = await isProductInCart(productId);
      if (alreadyInCart) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already added to cart. Edit quantity in cart.'),
          ),
        );
        return;
      }

      await addToCart(productId, quantity);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added to cart successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product to cart: ${e.toString()}'),
        ),
      );
    }
  }
}
