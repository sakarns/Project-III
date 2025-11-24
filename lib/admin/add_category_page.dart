import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:minimills/admin/view_category_page.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCategoryPage extends StatefulWidget {
  final String? categoryId;

  const AddCategoryPage({super.key, this.categoryId});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _loading = false;
  File? _selectedImage;
  String? _networkImageUrl;
  final String bucketName = 'category-images';

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) _loadCategoryData(widget.categoryId!);
  }

  Future<void> _loadCategoryData(String id) async {
    setState(() => _loading = true);
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null || !mounted) return;
      _nameController.text = response['name'] ?? '';
      if (response['image_url'] != null && response['image_url'].isNotEmpty) {
        _networkImageUrl = supabase.storage
            .from(bucketName)
            .getPublicUrl(response['image_url']);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted)
      setState(() => _selectedImage = File(image.path));
  }

  Future<void> _deleteOldImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final index = segments.indexOf('category_images');
      if (index != -1 && index + 1 < segments.length) {
        final filePath =
            'category_images/${segments.sublist(index + 1).join('/')}';
        await supabase.storage.from(bucketName).remove([filePath]);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final filePath = 'category_images/$fileName';
      await supabase.storage
          .from(bucketName)
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));
      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      String? imagePath = _networkImageUrl;
      if (_selectedImage != null) {
        if (widget.categoryId != null && _networkImageUrl != null)
          await _deleteOldImage(_networkImageUrl!);
        final uploaded = await _uploadImage(_selectedImage!);
        if (uploaded != null) imagePath = uploaded;
      }
      if (widget.categoryId != null) {
        await supabase
            .from('categories')
            .update({'name': name, 'image_url': imagePath})
            .eq('id', widget.categoryId as Object);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Category updated successfully!')),
        );
      } else {
        await supabase.from('categories').insert({
          'name': name,
          'image_url': imagePath,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Category added successfully!')),
        );
        _nameController.clear();
        setState(() => _selectedImage = null);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryId != null ? 'Edit Category' : 'Add Category',
        ),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewCategoryPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
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
                              'Tap to upload category image',
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
                labelText: 'Category Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveCategory,
                icon: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _loading
                      ? 'Saving...'
                      : (widget.categoryId != null
                            ? 'Update Category'
                            : 'Add Category'),
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
