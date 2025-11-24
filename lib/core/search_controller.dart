import '../shop/product_session.dart';

class SearchController {
  List<Map<String, dynamic>> searchAndSortProducts(String query) {
    if (query.isEmpty) return ProductSession.products;

    final lowerQuery = query.toLowerCase();

    final List<Map<String, dynamic>> searched = [];
    final List<Map<String, dynamic>> sameCategory = [];
    final List<Map<String, dynamic>> remaining = [];

    // Step 1: Find all products matching the query
    for (final p in ProductSession.products) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      if (name.contains(lowerQuery)) {
        searched.add(p);
      }
    }

    // Step 2: Find products in the same categories as searched, but not already in searched
    final searchedCategoryIds = searched.map((p) => p['category_id']).toSet();
    for (final p in ProductSession.products) {
      if (searched.contains(p)) continue;
      if (searchedCategoryIds.contains(p['category_id'])) {
        sameCategory.add(p);
      }
    }

    // Step 3: Remaining products not in searched or sameCategory
    for (final p in ProductSession.products) {
      if (!searched.contains(p) && !sameCategory.contains(p)) {
        remaining.add(p);
      }
    }

    return [...searched, ...sameCategory, ...remaining];
  }
}
