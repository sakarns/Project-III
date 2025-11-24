import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_product_page.dart';

class AddProductPage extends StatefulWidget {
  final String? productId;

  const AddProductPage({super.key, this.productId});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pricePerUnitController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedUnit;
  String? _networkImageUrl;
  String? _existingImagePath;
  List<dynamic> _categories = [];
  final List<String> _units = ['g', 'kg', 'liter', 'ml', 'packet'];
  File? _selectedImage;
  bool _loading = false;
  bool _inStock = true;
  double _totalPrice = 0.0;
  final String bucketName = 'product-images';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.productId != null) _loadProductData(widget.productId!);
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('categories').select().order('name');
      if (!mounted) return;
      setState(() => _categories = response);
    } catch (_) {}
  }

  Future<String?> _getSignedImageUrl(String path) async {
    if (path.isEmpty) return null;
    try {
      final url = await supabase.storage
          .from(bucketName)
          .createSignedUrl(path, 60 * 60);
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProductData(String id) async {
    setState(() => _loading = true);
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (!mounted || response == null) return;

      _nameController.text = response['name'] ?? '';
      _descriptionController.text = response['description'] ?? '';
      _quantityController.text = (response['quantity'] ?? '').toString();
      _pricePerUnitController.text = (response['price_per_unit'] ?? '')
          .toString();
      _sellingPriceController.text = (response['selling_price'] ?? '')
          .toString();
      _selectedCategory = (response['category_id'] ?? '').toString();
      _selectedUnit = response['unit'];
      _inStock = response['in_stock'] ?? true;
      _calculateTotalPrice();

      if (response['image_url'] != null && response['image_url'].isNotEmpty) {
        _existingImagePath = response['image_url'];
        _networkImageUrl = await _getSignedImageUrl(_existingImagePath!);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _calculateTotalPrice() {
    final q = double.tryParse(_quantityController.text.trim());
    final p = double.tryParse(_pricePerUnitController.text.trim());
    setState(() {
      _totalPrice = (q != null && p != null) ? q * p : 0.0;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted)
      setState(() => _selectedImage = File(image.path));
  }

  Future<void> _deleteOldImage(String imagePath) async {
    try {
      await supabase.storage.from(bucketName).remove([imagePath]);
    } catch (_) {}
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final filePath = 'product_images/$fileName';
      await supabase.storage
          .from(bucketName)
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      return filePath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final quantityText = _quantityController.text.trim();
    final pricePerUnitText = _pricePerUnitController.text.trim();
    final sellingPriceText = _sellingPriceController.text.trim();

    if (name.isEmpty ||
        description.isEmpty ||
        quantityText.isEmpty ||
        pricePerUnitText.isEmpty ||
        sellingPriceText.isEmpty ||
        _selectedCategory == null ||
        (_selectedImage == null && _networkImageUrl == null) ||
        _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ All fields are required')),
      );
      return;
    }

    final quantity = double.tryParse(quantityText);
    final pricePerUnit = double.tryParse(pricePerUnitText);
    final sellingPrice = double.tryParse(sellingPriceText);

    if (quantity == null || pricePerUnit == null || sellingPrice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('⚠️ Invalid number format')));
      return;
    }

    _calculateTotalPrice();
    setState(() => _loading = true);

    try {
      String? imagePath = _existingImagePath;

      // If new image selected, delete old image and upload new
      if (_selectedImage != null) {
        if (_existingImagePath != null) {
          await _deleteOldImage(_existingImagePath!);
        }
        final uploaded = await _uploadImage(_selectedImage!);
        if (uploaded != null) imagePath = uploaded;
      }

      if (widget.productId != null) {
        // Update existing product
        await supabase
            .from('products')
            .update({
              'name': name,
              'description': description,
              'category_id': int.parse(_selectedCategory!),
              'image_url': imagePath,
              'in_stock': _inStock,
              'quantity': quantity,
              'unit': _selectedUnit,
              'price_per_unit': pricePerUnit,
              'total_price': _totalPrice,
              'selling_price': sellingPrice,
            })
            .eq('id', int.parse(widget.productId!));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product updated successfully!')),
        );
      } else {
        // Insert new product
        await supabase.from('products').insert({
          'name': name,
          'description': description,
          'category_id': int.parse(_selectedCategory!),
          'image_url': imagePath,
          'in_stock': _inStock,
          'quantity': quantity,
          'unit': _selectedUnit,
          'price_per_unit': pricePerUnit,
          'total_price': _totalPrice,
          'selling_price': sellingPrice,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product added successfully!')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ Error saving product: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId != null ? 'Edit Product' : 'Add Product'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewProductPage()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.withAlpha(50),
                        border: Border.all(color: Colors.grey.withAlpha(100)),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : (_networkImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_networkImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                      ),
                      child: _selectedImage == null && _networkImageUrl == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to upload product image',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                          onChanged: (_) => _calculateTotalPrice(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          items: _units
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedUnit = val),
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pricePerUnitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price per Unit (NRP)',
                      prefixText: '₨ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: (_) => _calculateTotalPrice(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Price: ₨ ${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sellingPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Selling Price (NRP)',
                      prefixText: '₨ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: _categories.map<DropdownMenuItem<String>>((cat) {
                      return DropdownMenuItem(
                        value: cat['id'].toString(),
                        child: Text(cat['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    decoration: const InputDecoration(
                      labelText: 'Select Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('In Stock'),
                    value: _inStock,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (v) => setState(() => _inStock = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _saveProduct,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _loading
                            ? 'Saving...'
                            : (widget.productId != null
                                  ? 'Update Product'
                                  : 'Add Product'),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
