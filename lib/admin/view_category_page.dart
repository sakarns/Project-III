import 'package:flutter/material.dart';
import 'add_category_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewCategoryPage extends StatefulWidget {
  const ViewCategoryPage({super.key});

  @override
  State<ViewCategoryPage> createState() => _ViewCategoryPageState();
}

class _ViewCategoryPageState extends State<ViewCategoryPage> {
  final supabase = Supabase.instance.client;
  final String bucketName = 'category-images';
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _searchVisible = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<String?> _getSignedImageUrl(String path) async {
    if (path.isEmpty) return null;
    try {
      final signedUrl = await supabase.storage
          .from(bucketName)
          .createSignedUrl(path, 60 * 60);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _loading = true);
    try {
      final response = await supabase
          .from('categories')
          .select()
          .order('created_at', ascending: false);
      final List<dynamic> categoriesWithUrls = [];
      for (var cat in response) {
        final imagePath = cat['image_url'];
        if (imagePath != null && imagePath.isNotEmpty) {
          final signedUrl = await _getSignedImageUrl(imagePath);
          cat['signed_url'] = signedUrl;
        }
        categoriesWithUrls.add(cat);
      }
      if (!mounted) return;
      setState(() {
        _categories = categoriesWithUrls;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCategory(int id, String? imagePath) async {
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        await supabase.storage.from(bucketName).remove([imagePath]);
      }
      await supabase.from('categories').delete().eq('id', id);
      _fetchCategories();
    } catch (_) {}
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((cat) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                decoration: const InputDecoration(
                  hintText: 'Search categories...',
                  border: InputBorder.none,
                ),
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Categories'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCategoryPage()),
              );
              if (mounted) _fetchCategories();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : filteredCategories.isEmpty
          ? const Center(child: Text('No categories found'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final cat = filteredCategories[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child:
                            cat['signed_url'] != null &&
                                cat['signed_url'].toString().isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  cat['signed_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                      ),
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  color: Colors.grey,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.category,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4,
                        ),
                        child: Center(
                          child: Text(
                            cat['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddCategoryPage(
                                        categoryId: cat['id'].toString(),
                                      ),
                                    ),
                                  );
                                  if (mounted) _fetchCategories();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('Delete'),
                                onPressed: () async {
                                  await _deleteCategory(
                                    cat['id'],
                                    cat['image_url'],
                                  );
                                  if (mounted) _fetchCategories();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
