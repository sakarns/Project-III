import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchPendingDeliveries({int limit = 3}) async {
    final List<dynamic> rows = await supabase
        .from('checkout')
        .select('id, delivery_lat, delivery_lng, delivery_address')
        .eq('order_status', 'Pending')
        .order('created_at', ascending: true)
        .limit(limit);

    return rows
        .where((row) => row['delivery_lat'] != null && row['delivery_lng'] != null)
        .map((row) => {
      'id': row['id'],
      'lat': row['delivery_lat'],
      'lng': row['delivery_lng'],
      'address': row['delivery_address'],
    })
        .toList();
  }

  static LatLng millLocation() {
    return const LatLng(27.677951747746903, 85.36581695562414);
  }
}
