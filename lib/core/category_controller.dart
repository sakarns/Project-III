import 'package:flutter/material.dart';
import '../shop/product_session.dart';

class CategoryController {
  Widget buildCategoryList({
    required int? selectedCategoryId,
    required ColorScheme colors,
    required void Function(int? id) onCategoryTap,
  }) {
    final categories = ProductSession.categories;

    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.isEmpty ? 3 : categories.length,
        itemBuilder: (context, index) {
          if (categories.isEmpty) return _placeholder(colors);
          final cat = categories[index];
          final isSelected = selectedCategoryId == cat['id'];
          return GestureDetector(
            onTap: () => onCategoryTap(isSelected ? null : cat['id']),
            child: _categoryTile(cat, colors, isSelected),
          );
        },
      ),
    );
  }

  // Grid view
  Widget buildCategoryGrid(
    List<Map<String, dynamic>> categories,
    ColorScheme colors,
    int? selectedCategoryId,
    void Function(int? id) onTap,
  ) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 0.2,
        childAspectRatio: 0.705,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = selectedCategoryId == cat['id'];
        return GestureDetector(
          onTap: () => onTap(isSelected ? null : cat['id']),
          child: _categoryTile(cat, colors, isSelected),
        );
      },
    );
  }

  Widget _categoryTile(
    Map<String, dynamic> cat,
    ColorScheme colors,
    bool selected,
  ) {
    final name = cat['name'] ?? 'Category';
    final imageUrl = cat['image_url'] ?? '';
    return Container(
      width: 108,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Container(
                        color: colors.surface,
                        child: Icon(
                          Icons.broken_image,
                          size: 100,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: colors.surface,
                      child: Icon(
                        Icons.category,
                        size: 100,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme colors) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(Icons.category, size: 100, color: colors.onSurfaceVariant),
      ),
    );
  }
}
