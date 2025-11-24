import 'package:supabase_flutter/supabase_flutter.dart';
import '../shop/product_session.dart';
import '../user/user_session.dart';

class RecomController {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _recommended = [];

  Future<void> loadRecommendations({int topN = 8}) async {
    final currentUserId = UserSession.userId;
    if (currentUserId == null) {
      _recommended = [];
      return;
    }

    final orderRows = await supabase.from('order_history').select('user_id, product_id');
    final _ = await supabase.from('checkout_history').select('id, user_id, created_at');

    final Map<String, Set<int>> userPurchases = {};
    for (var r in orderRows) {
      final uid = r['user_id']?.toString();
      final pid = (r['product_id'] is int)
          ? r['product_id'] as int
          : int.tryParse(r['product_id'].toString());
      if (uid == null || pid == null) continue;
      userPurchases.putIfAbsent(uid, () => <int>{}).add(pid);
    }

    final Set<int> currentUserProducts =
        userPurchases[currentUserId.toString()] ?? <int>{};

    final Map<int, int> popularity = {};
    for (var entry in userPurchases.entries) {
      for (var pid in entry.value) {
        popularity[pid] = (popularity[pid] ?? 0) + 1;
      }
    }

    final Map<int, Map<int, int>> cooccurrence = {};
    for (var entry in userPurchases.entries) {
      final products = entry.value.toList();
      for (int i = 0; i < products.length; i++) {
        for (int j = 0; j < products.length; j++) {
          if (i == j) continue;
          cooccurrence.putIfAbsent(products[i], () => {});
          cooccurrence[products[i]]![products[j]] =
              (cooccurrence[products[i]]![products[j]] ?? 0) + 1;
        }
      }
    }

    final Map<int, double> scores = {};
    const double wCollab = 0.5;
    const double wItem = 0.3;
    const double wPop = 0.2;

    final Set<String> otherUsers =
    userPurchases.keys.where((k) => k != currentUserId.toString()).toSet();

    for (var other in otherUsers) {
      final Set<int> otherSet = userPurchases[other] ?? <int>{};
      final Set<int> intersection = currentUserProducts.intersection(otherSet);
      final Set<int> union = currentUserProducts.union(otherSet);
      final double sim = union.isEmpty ? 0.0 : intersection.length / union.length;
      if (sim <= 0) continue;
      for (var pid in otherSet) {
        if (currentUserProducts.contains(pid)) continue;
        scores[pid] = (scores[pid] ?? 0) + sim * wCollab;
      }
    }

    for (var pid in currentUserProducts) {
      final related = cooccurrence[pid] ?? {};
      for (var entry in related.entries) {
        final relatedPid = entry.key;
        if (currentUserProducts.contains(relatedPid)) continue;
        scores[relatedPid] =
            (scores[relatedPid] ?? 0) + entry.value.toDouble() * wItem;
      }
    }

    final int maxPop =
    popularity.isEmpty ? 1 : popularity.values.reduce((a, b) => a > b ? a : b);

    for (var pid in popularity.keys) {
      if (currentUserProducts.contains(pid)) continue;
      final norm = popularity[pid]! / maxPop;
      scores[pid] = (scores[pid] ?? 0) + norm * wPop;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<int> recommendedIds =
    sorted.map((e) => e.key).take(topN).toList();

    final allProducts = ProductSession.products;
    final Set<int> recommendedSet = recommendedIds.toSet();

    _recommended = allProducts
        .where((p) {
      final pid = (p['id'] is int)
          ? p['id'] as int
          : int.tryParse(p['id'].toString());
      return pid != null && recommendedSet.contains(pid);
    })
        .toList();

    if (_recommended.length < topN) {
      final Set<int> existing = _recommended
          .map((p) => (p['id'] is int)
          ? p['id'] as int
          : int.tryParse(p['id'].toString()) ?? -1)
          .toSet();

      final fallback = popularity.keys
          .where((k) => !currentUserProducts.contains(k) && !existing.contains(k))
          .toList()
        ..sort((a, b) => (popularity[b] ?? 0).compareTo(popularity[a] ?? 0));

      for (var fid in fallback) {
        if (_recommended.length >= topN) break;
        final prod = allProducts.firstWhere(
              (p) {
            final pid = (p['id'] is int)
                ? p['id'] as int
                : int.tryParse(p['id'].toString());
            return pid == fid;
          },
          orElse: () => {},
        );
        if (prod.isNotEmpty) _recommended.add(prod);
      }
    }
  }

  List<Map<String, dynamic>> get recommended => _recommended;
}
