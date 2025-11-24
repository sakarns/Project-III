import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_session.dart';

class ProductService {
  final supabase = Supabase.instance.client;
  final String categoryBucket = 'category-images';
  final String productBucket = 'product-images';

  Future<String?> _getSignedUrl(String bucket, String path) async {
    if (path.isEmpty) return null;
    try {
      return await supabase.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  String formatNumber(dynamic value) {
    if (value == null) return '0';
    double number = 0;
    if (value is int) {
      number = value.toDouble();
    } else if (value is double) {
      number = value;
    } else {
      number = double.tryParse(value.toString()) ?? 0;
    }
    if (number % 1 == 0) {
      return number.toInt().toString();
    } else {
      return number.toString();
    }
  }

  Future<void> loadProductsAndCategories() async {
    try {
      final catResponse = await supabase
          .from('categories')
          .select()
          .order('created_at', ascending: false);
      ProductSession.categories = await Future.wait(
        (catResponse as List<dynamic>).map((c) async {
          final imagePath = (c['image_url'] ?? '').toString();
          final cleanedPath = imagePath.contains('/')
              ? imagePath.split('/').last
              : imagePath;
          final url = await _getSignedUrl(
            categoryBucket,
            'category_images/$cleanedPath',
          );
          return {...Map<String, dynamic>.from(c), 'image_url': url};
        }).toList(),
      );

      final prodResponse = await supabase
          .from('products')
          .select('*, categories(name)')
          .order('created_at', ascending: false);
      ProductSession.products = await Future.wait(
        (prodResponse as List<dynamic>).map<Future<Map<String, dynamic>>>((
          p,
        ) async {
          final mapP = Map<String, dynamic>.from(p);
          final imageName = (mapP['image_url'] ?? '')
              .toString()
              .split('/')
              .last;
          final path = imageName.isNotEmpty ? 'product_images/$imageName' : '';
          final signedUrl = path.isNotEmpty
              ? await _getSignedUrl(productBucket, path)
              : null;
          return {...mapP, 'image_path': path, 'signed_image_url': signedUrl};
        }).toList(),
      );
    } catch (_) {
      ProductSession.categories = [];
      ProductSession.products = [];
    }
  }
}
