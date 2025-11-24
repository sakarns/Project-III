import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/user_session.dart';
import 'product_session.dart';

class FavoriteService {
  final supabase = Supabase.instance.client;
  final String productBucket = 'product-images';

  Future<List<int>> getUserFavorites() async {
    final userId = UserSession.userId;
    if (userId == null) return [];
    final response = await supabase
        .from('favorites')
        .select('product_id')
        .eq('user_id', userId);
    return (response as List<dynamic>)
        .map((e) => (e['product_id'] as num).toInt())
        .toList();
  }

  Future<void> toggleFavorite(int productId) async {
    final userId = UserSession.userId;
    if (userId == null) return;
    final existing = await supabase
        .from('favorites')
        .select('user_id, product_id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing != null) {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } else {
      await supabase.from('favorites').insert({
        'user_id': userId,
        'product_id': productId,
      });
    }
  }

  Future<String?> getProductSignedUrl(String path) async {
    if (path.isEmpty) return null;
    try {
      return await supabase.storage
          .from(productBucket)
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> loadFavoriteProducts(
    List<int> favoriteIds,
  ) async {
    List<Map<String, dynamic>> favProducts = [];
    for (var product in ProductSession.products) {
      if (favoriteIds.contains(product['id'])) {
        final imageUrl = (product['image_url'] ?? '').toString();
        String? signedUrl;
        if (imageUrl.isNotEmpty) {
          final imageName = imageUrl.split('/').last;
          signedUrl = await getProductSignedUrl('product_images/$imageName');
        }
        favProducts.add({
          ...Map<String, dynamic>.from(product),
          'signed_image_url': signedUrl,
        });
      }
    }
    return favProducts;
  }
}
