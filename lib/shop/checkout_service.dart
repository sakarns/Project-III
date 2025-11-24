import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchCheckouts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final res = await supabase
        .from('checkout')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: true);
    if (res.isEmpty) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchOrdersByCheckout(
    Map<String, dynamic> checkout,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    final checkoutTime =
        DateTime.tryParse(checkout['created_at'] ?? '') ?? DateTime.now();
    final DateTime? nextTime = checkout['next_checkout_created_at'];
    final res = await supabase
        .from('orders')
        .select('*, products(*)')
        .eq('user_id', user.id)
        .filter('updated_at', 'gte', checkoutTime.toIso8601String())
        .filter(
          'updated_at',
          nextTime != null ? 'lt' : 'gte',
          nextTime?.toIso8601String() ?? checkoutTime.toIso8601String(),
        )
        .order('updated_at', ascending: true);
    if (res.isEmpty) return [];
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateCheckoutStatus(int checkoutId, String status) async {
    await supabase
        .from('checkout')
        .update({'order_status': status})
        .eq('id', checkoutId);
  }
}
