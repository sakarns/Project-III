import 'package:flutter/material.dart' hide SearchController;
import 'package:minimills/shop/product_service.dart';
import 'package:radio_group_v2/radio_group_v2.dart' as rg;
import '../core/product_controller.dart';
import '../core/category_controller.dart';
import '../core/search_controller.dart';
import 'product_session.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

enum SortOption { priceAsc, priceDesc, sellingPriceAsc, sellingPriceDesc, fifo, lifo }

class _ShopPageState extends State<ShopPage> {
  //TimSort -  a hybrid merge-insertion sort algorithm.
  bool isLoading = true;
  int? selectedCategoryId;
  String searchQuery = '';
  SortOption? sortOption;
  RangeValues priceRange = const RangeValues(0, 100000);
  RangeValues sellingPriceRange = const RangeValues(0, 100000);
  RangeValues quantityRange = const RangeValues(0, 1000);
  bool showInStockOnly = false;
  bool gridViewProducts = false;
  bool gridViewCategories = false;

  final ProductController productController = ProductController();
  final CategoryController categoryController = CategoryController();
  final SearchController searchController = SearchController();

  List<Map<String, dynamic>> filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await ProductService().loadProductsAndCategories();
    await productController.favoriteController.loadFavorites();
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  void _applyFilters() {
    var products = searchQuery.isEmpty
        ? ProductSession.products
        : searchController.searchAndSortProducts(searchQuery);

    filteredProducts = products.where((p) {
      final matchesCategory = selectedCategoryId == null || p['category_id'] == selectedCategoryId;
      final price = (p['price_per_unit'] ?? 0).toDouble();
      final selling = (p['selling_price'] ?? 0).toDouble();
      final qty = (p['quantity'] ?? 0).toDouble();
      final stock = p['in_stock'] ?? true;

      return matchesCategory &&
          price >= priceRange.start &&
          price <= priceRange.end &&
          selling >= sellingPriceRange.start &&
          selling <= sellingPriceRange.end &&
          qty >= quantityRange.start &&
          qty <= quantityRange.end &&
          (!showInStockOnly || stock);
    }).toList();

    if (sortOption != null) {
      filteredProducts.sort((a, b) {
        switch (sortOption!) {
          case SortOption.priceAsc:
            return (a['price_per_unit'] ?? 0).compareTo(b['price_per_unit'] ?? 0);
          case SortOption.priceDesc:
            return (b['price_per_unit'] ?? 0).compareTo(a['price_per_unit'] ?? 0);
          case SortOption.sellingPriceAsc:
            return (a['selling_price'] ?? 0).compareTo(b['selling_price'] ?? 0);
          case SortOption.sellingPriceDesc:
            return (b['selling_price'] ?? 0).compareTo(a['selling_price'] ?? 0);
          case SortOption.fifo:
            return a['created_at'].toString().compareTo(b['created_at'].toString());
          case SortOption.lifo:
            return b['created_at'].toString().compareTo(a['created_at'].toString());
        }
      });
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sort Options", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    rg.RadioGroup<SortOption>(
                      values: SortOption.values,
                      labelBuilder: (option) {
                        switch (option) {
                          case SortOption.priceAsc:
                            return const Text("Price: Low → High");
                          case SortOption.priceDesc:
                            return const Text("Price: High → Low");
                          case SortOption.sellingPriceAsc:
                            return const Text("Selling Price: Low → High");
                          case SortOption.sellingPriceDesc:
                            return const Text("Selling Price: High → Low");
                          case SortOption.fifo:
                            return const Text("Date Added: Oldest → Newest");
                          case SortOption.lifo:
                            return const Text("Date Added: Newest → Oldest");
                        }
                      },
                      indexOfDefault: sortOption != null ? SortOption.values.indexOf(sortOption!) : -1,
                      orientation: rg.RadioGroupOrientation.vertical,
                      onChanged: (value) => setSheetState(() => sortOption = value),
                    ),
                    const SizedBox(height: 12),
                    const Text("Filter Options", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    _buildRangeSlider("Price/unit Range", priceRange, 0, 100000, 100, (v) => setSheetState(() => priceRange = v)),
                    _buildRangeSlider("Selling Price Range", sellingPriceRange, 0, 100000, 100, (v) => setSheetState(() => sellingPriceRange = v)),
                    _buildRangeSlider("Quantity Range", quantityRange, 0, 1000, 100, (v) => setSheetState(() => quantityRange = v)),
                    CheckboxListTile(
                      title: const Text("In Stock Only"),
                      value: showInStockOnly,
                      onChanged: (v) => setSheetState(() => showInStockOnly = v ?? false),
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _applyFilters());
                        },
                        child: const Text("Apply"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRangeSlider(String title, RangeValues values, double min, double max, int divisions, ValueChanged<RangeValues> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          labels: RangeLabels(values.start.toString(), values.end.toString()),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('*** Shop Here ***'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadInitialData,
        color: colors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.onSurface)),
                  IconButton(
                    icon: Icon(gridViewCategories ? Icons.view_list : Icons.grid_view),
                    onPressed: () => setState(() => gridViewCategories = !gridViewCategories),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              gridViewCategories
                  ? categoryController.buildCategoryGrid(
                ProductSession.categories,
                colors,
                selectedCategoryId,
                    (id) {
                  setState(() {
                    selectedCategoryId = id;
                    _applyFilters();
                  });
                },
              )
                  : categoryController.buildCategoryList(
                selectedCategoryId: selectedCategoryId,
                colors: colors,
                onCategoryTap: (id) {
                  setState(() {
                    selectedCategoryId = id;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.onSurface)),
                  IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _openFilterSheet,
                    ),
                  IconButton(
                    icon: Icon(gridViewProducts ? Icons.view_list : Icons.grid_view),
                    onPressed: () => setState(() => gridViewProducts = !gridViewProducts),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              gridViewProducts
                  ? productController.buildProductGrid(filteredProducts, colors, context)
                  : productController.buildProductList(filteredProducts, colors, context),
            ],
          ),
        ),
      ),
    );
  }
}
