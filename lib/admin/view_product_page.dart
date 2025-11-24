import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_product_page.dart';
import 'package:radio_group_v2/radio_group_v2.dart' as rg;

enum SortOption {
  priceAsc,
  priceDesc,
  sellingPriceAsc,
  sellingPriceDesc,
  fifo,
  lifo,
}

class ViewProductPage extends StatefulWidget {
  const ViewProductPage({super.key});

  @override
  State<ViewProductPage> createState() => _ViewProductPageState();
}

class _ViewProductPageState extends State<ViewProductPage> {
  final supabase = Supabase.instance.client;
  final String bucketName = 'product-images';
  List<dynamic> _products = [];
  List<dynamic> _displayProducts = [];
  bool _loading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Filter variables
  SortOption? sortOption;
  RangeValues priceRange = const RangeValues(0, 100000);
  RangeValues sellingPriceRange = const RangeValues(0, 100000);
  RangeValues quantityRange = const RangeValues(0, 1000);
  bool showInStockOnly = false;
  bool showOutOfStockOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getSignedUrl(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    try {
      final signedUrl = await supabase.storage
          .from(bucketName)
          .createSignedUrl(filePath, 60 * 60);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);
    try {
      final response = await supabase
          .from('products')
          .select('*, categories(name)')
          .order('created_at', ascending: false);
      final List<dynamic> withUrls = [];
      for (var p in response) {
        String? imagePath = p['image_url'];
        if (imagePath != null &&
            imagePath.isNotEmpty &&
            !imagePath.startsWith('product_images/')) {
          imagePath = 'product_images/${imagePath.split('/').last}';
        }
        final signedUrl = await _getSignedUrl(imagePath);
        withUrls.add({
          ...p,
          'signed_image_url': signedUrl,
          'image_path': imagePath,
        });
      }
      if (!mounted) return;
      setState(() {
        _products = withUrls;
        _displayProducts = withUrls;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteProduct(int id, String? imagePath) async {
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        await supabase.storage.from(bucketName).remove([imagePath]);
      }
      await supabase.from('products').delete().eq('id', id);
      _fetchProducts();
    } catch (_) {}
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _displayProducts = _products);
      return;
    }
    final results = _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final category = (p['categories']?['name'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
    if (results.isNotEmpty) {
      final top = results.first;
      final related = _products.where(
        (p) =>
            p['categories']?['name'] == top['categories']?['name'] && p != top,
      );
      setState(() => _displayProducts = [top, ...related]);
    } else {
      setState(() => _displayProducts = _products);
    }
  }

  void _applyFilters() {
    var products = List<dynamic>.from(_products);

    products = products.where((p) {
      final price = (p['price_per_unit'] ?? 0).toDouble();
      final selling = (p['selling_price'] ?? 0).toDouble();
      final qty = (p['quantity'] ?? 0).toDouble();
      final stock = p['in_stock'] ?? true;

      final stockCondition =
          (showInStockOnly && stock) ||
          (showOutOfStockOnly && !stock) ||
          (!showInStockOnly && !showOutOfStockOnly);

      return price >= priceRange.start &&
          price <= priceRange.end &&
          selling >= sellingPriceRange.start &&
          selling <= sellingPriceRange.end &&
          qty >= quantityRange.start &&
          qty <= quantityRange.end &&
          stockCondition;
    }).toList();

    if (sortOption != null) {
      products.sort((a, b) {
        switch (sortOption!) {
          case SortOption.priceAsc:
            return (a['price_per_unit'] ?? 0).compareTo(
              b['price_per_unit'] ?? 0,
            );
          case SortOption.priceDesc:
            return (b['price_per_unit'] ?? 0).compareTo(
              a['price_per_unit'] ?? 0,
            );
          case SortOption.sellingPriceAsc:
            return (a['selling_price'] ?? 0).compareTo(b['selling_price'] ?? 0);
          case SortOption.sellingPriceDesc:
            return (b['selling_price'] ?? 0).compareTo(a['selling_price'] ?? 0);
          case SortOption.fifo:
            return a['created_at'].toString().compareTo(
              b['created_at'].toString(),
            );
          case SortOption.lifo:
            return b['created_at'].toString().compareTo(
              a['created_at'].toString(),
            );
        }
      });
    }

    setState(() => _displayProducts = products);
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sort Options",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
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
                      indexOfDefault: sortOption != null
                          ? SortOption.values.indexOf(sortOption!)
                          : -1,
                      orientation: rg.RadioGroupOrientation.vertical,
                      onChanged: (value) =>
                          setSheetState(() => sortOption = value),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Filter Options",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    _buildRangeSlider(
                      "Price/unit Range",
                      priceRange,
                      0,
                      100000,
                      100,
                      (v) => setSheetState(() => priceRange = v),
                    ),
                    _buildRangeSlider(
                      "Selling Price Range",
                      sellingPriceRange,
                      0,
                      100000,
                      100,
                      (v) => setSheetState(() => sellingPriceRange = v),
                    ),
                    _buildRangeSlider(
                      "Quantity Range",
                      quantityRange,
                      0,
                      1000,
                      100,
                      (v) => setSheetState(() => quantityRange = v),
                    ),
                    CheckboxListTile(
                      title: const Text("In Stock Only"),
                      value: showInStockOnly,
                      onChanged: (v) =>
                          setSheetState(() => showInStockOnly = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("Out of Stock Only"),
                      value: showOutOfStockOnly,
                      onChanged: (v) =>
                          setSheetState(() => showOutOfStockOnly = v ?? false),
                    ),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyFilters();
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

  Widget _buildRangeSlider(
    String title,
    RangeValues values,
    double min,
    double max,
    int divisions,
    ValueChanged<RangeValues> onChanged,
  ) {
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
    return Scaffold(
      appBar: AppBar(
        title: !_isSearching
            ? const Text('Products')
            : TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search shop...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white60),
                ),
                style: const TextStyle(color: Colors.white),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _displayProducts = _products;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProductPage()),
              );
              _fetchProducts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _displayProducts.isEmpty
          ? const Center(child: Text('No products found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _displayProducts.length,
              itemBuilder: (context, index) {
                final product = _displayProducts[index];
                final name = product['name'] ?? '';
                final category = product['categories']?['name'] ?? '';
                final pricePerUnit = product['price_per_unit'] ?? 0;
                final quantity = product['quantity'] ?? 0;
                final unit = product['unit'] ?? '';
                final totalPrice = product['total_price'] ?? 0;
                final sellingPrice = product['selling_price'] ?? 0;
                final imageUrl = product['signed_image_url'];
                final imagePath = product['image_path'];
                final inStock = product['in_stock'] ?? true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 120,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade300,
                                image: imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageUrl == null
                                  ? const Icon(Icons.image_not_supported)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddProductPage(
                                          productId: product['id'].toString(),
                                        ),
                                      ),
                                    );
                                    _fetchProducts();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    await _deleteProduct(
                                      product['id'],
                                      imagePath,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Category: $category'),
                              const SizedBox(height: 4),
                              Text('Quantity: $quantity  $unit'),
                              const SizedBox(height: 4),
                              Text('Price per $unit: Rs. $pricePerUnit'),
                              const SizedBox(height: 4),
                              Text('Total Price: Rs. $totalPrice'),
                              const SizedBox(height: 4),
                              Text('Selling Price: Rs. $sellingPrice'),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${inStock ? "In Stock" : "Out of Stock"}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: inStock ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
