import 'package:flutter/material.dart';
import '../shop/favorite_service.dart';

class FavoriteController {
  final FavoriteService favoriteService = FavoriteService();
  final Set<int> _processing = {};
  final Set<int> _favoriteIds = {};

  Set<int> get favoriteIds => _favoriteIds;

  bool isProcessing(int productId) => _processing.contains(productId);

  Future<void> loadFavorites() async {
    final ids = await favoriteService.getUserFavorites();
    _favoriteIds
      ..clear()
      ..addAll(ids);
  }

  Future<void> toggleFavorite(
    BuildContext context,
    int productId, {
    VoidCallback? onUpdate,
  }) async {
    if (_processing.contains(productId)) return;
    _processing.add(productId);
    if (context.mounted) (context as Element).markNeedsBuild();

    await favoriteService.toggleFavorite(productId);

    // Update local favorite IDs after toggling
    await loadFavorites();

    _processing.remove(productId);
    if (context.mounted) (context as Element).markNeedsBuild();
    onUpdate?.call();
  }

  Widget favoriteIcon(
    int productId,
    BuildContext context, [
    VoidCallback? onUpdate,
  ]) {
    final isFav = _favoriteIds.contains(productId);
    final loading = isProcessing(productId);

    return GestureDetector(
      onTap: loading
          ? null
          : () => toggleFavorite(context, productId, onUpdate: onUpdate),
      child: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? Colors.red : Colors.redAccent,
        size: 22,
      ),
    );
  }
}
