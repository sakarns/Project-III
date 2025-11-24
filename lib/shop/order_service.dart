import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final supabase = Supabase.instance.client;

  Future<void> placeOrders(List<Map<String, dynamic>> orderItems) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    for (var order in orderItems) {
      await supabase.from('orders').insert({
        'user_id': user.id,
        'product_id': order['product_id'],
        'order_quantity': order['order_quantity'],
        'total_price': order['total_price'],
        'discount': order['discount'],
        'describe_requirements': order['describe_requirements'],
        'cart_id': order['cart_id'],
      });
    }
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final response = await supabase
        .from('orders')
        .select('*, products(*)')
        .eq('user_id', user.id)
        .eq('is_checkout', false) as List<dynamic>? ?? [];
    return response.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<int> getCheckoutCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;
    final response = await supabase
        .from('checkout')
        .select('id')
        .eq('user_id', user.id) as List<dynamic>?;

    return response?.length ?? 0;
  }

  Future<void> createCheckout({
    required double totalAmount,
    required double totalDiscount,
    required String paymentMethod,
    required String deliveryDescription,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryAddress,
    required DateTime createdAt,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('checkout').insert({
      'user_id': user.id,
      'total_amount': totalAmount,
      'total_discount': totalDiscount,
      'payment_method': paymentMethod,
      'delivery_description': deliveryDescription,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'delivery_address': deliveryAddress,
      'created_at': createdAt.toIso8601String(),
    });
  }

  Future<void> updateOrderCheckoutStatus({
    required int orderId,
    required bool isCheckout,
    required DateTime updatedAt,
  }) async {
    await supabase
        .from('orders')
        .update({
      'is_checkout': isCheckout,
      'updated_at': updatedAt.toIso8601String(),
    })
        .eq('id', orderId);
  }

  Future<void> deleteCartItem(int cartId) async {
    await supabase.from('cart').delete().eq('id', cartId);
  }

  Future<void> deleteOrder(int orderId) async {
    await supabase.from('orders').delete().eq('id', orderId);
  }
}
