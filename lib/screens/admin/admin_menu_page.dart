import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virundhu/screens/core/profile_page.dart';
import 'package:virundhu/services/menu_service.dart';

class AdminMenuPage extends StatefulWidget {
  final bool showAppBar;

  const AdminMenuPage({super.key, this.showAppBar = true});

  @override
  State<AdminMenuPage> createState() => _AdminMenuPageState();
}

class _AdminMenuPageState extends State<AdminMenuPage> {
  late Future<List<Map<String, dynamic>>> _menuFuture;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _menuFuture = MenuService.fetchAllMenuAdmin();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = MenuService.fetchAllMenuAdmin();
    setState(() {
      _menuFuture = future;
    });
    await future;
  }

  String _display(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> items) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      final tags = ((item['tags'] as List?) ?? const [])
          .map((tag) => tag.toString().toLowerCase())
          .join(' ');
      return _display(item['name']).toLowerCase().contains(query) ||
          _display(item['category']).toLowerCase().contains(query) ||
          tags.contains(query);
    }).toList();
  }

  Future<String?> _pickAndUploadImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final user = Supabase.instance.client.auth.currentUser;
    final ext = picked.path.split('.').last;
    final fileName = '${user?.id ?? 'admin'}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await File(picked.path).readAsBytes();

    try {
      await Supabase.instance.client.storage.createBucket(
        'menu-images',
        const BucketOptions(public: true),
      );
    } catch (_) {}

    await Supabase.instance.client.storage.from('menu-images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return Supabase.instance.client.storage.from('menu-images').getPublicUrl(fileName);
  }

  Future<void> _showMenuEditor({Map<String, dynamic>? item}) async {
    final nameCtrl = TextEditingController(text: _display(item?['name'], fallback: ''));
    final priceCtrl = TextEditingController(
      text: item?['price']?.toString() ?? '',
    );
    final categoryCtrl = TextEditingController(
      text: _display(item?['category'], fallback: ''),
    );
    final tagsCtrl = TextEditingController(
      text: ((item?['tags'] as List?) ?? const []).join(', '),
    );

    var imageUrl = _display(item?['image_url'], fallback: '');
    var isAvailable = item?['is_available'] != false;
    var isTrending = item?['is_trending'] == true;
    var isSaving = false;
    var isUploading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> save() async {
              final name = nameCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text.trim());
              final category = categoryCtrl.text.trim();

              if (name.isEmpty || price == null || category.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, price and category are required')),
                );
                return;
              }

              setSheetState(() {
                isSaving = true;
              });

              try {
                await MenuService.saveMenuItem(
                  id: item?['id'],
                  name: name,
                  price: price,
                  category: category,
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  tags: tagsCtrl.text
                      .split(',')
                      .map((tag) => tag.trim())
                      .where((tag) => tag.isNotEmpty)
                      .toList(),
                  isAvailable: isAvailable,
                  isTrending: isTrending,
                );
                if (!mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(item == null ? 'Dish added' : 'Dish updated'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
                await _refresh();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save dish: $error'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              } finally {
                if (mounted) {
                  setSheetState(() {
                    isSaving = false;
                  });
                }
              }
            }

            Future<void> uploadImage() async {
              setSheetState(() {
                isUploading = true;
              });
              try {
                final uploadedUrl = await _pickAndUploadImage();
                if (uploadedUrl != null) {
                  setSheetState(() {
                    imageUrl = uploadedUrl;
                  });
                }
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Image upload failed: $error'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              } finally {
                if (mounted) {
                  setSheetState(() {
                    isUploading = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item == null ? 'Add Dish' : 'Edit Dish',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Dish Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                          hintText: 'Veg, Starters, Spicy',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 140,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isUploading ? null : uploadImage,
                              icon: isUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_outlined),
                              label: Text(isUploading ? 'Uploading...' : 'Upload Image'),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: isAvailable,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available'),
                        onChanged: (value) {
                          setSheetState(() {
                            isAvailable = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        value: isTrending,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Featured / Trending'),
                        onChanged: (value) {
                          setSheetState(() {
                            isTrending = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(isSaving ? 'Saving...' : 'Save Dish'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item) async {
    final nextValue = item['is_available'] == false;
    try {
      await MenuService.setAvailability(id: item['id'], isAvailable: nextValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextValue ? 'Dish marked available' : 'Dish marked out of stock'),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update availability: $error')),
      );
    }
  }

  Future<void> _toggleTrending(Map<String, dynamic> item) async {
    final nextValue = item['is_trending'] != true;
    try {
      await MenuService.setTrending(id: item['id'], isTrending: nextValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextValue ? 'Dish added to featured list' : 'Dish removed from featured list'),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update featured state: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Menu Management', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.red.shade700,
              actions: [
                IconButton(
                  tooltip: 'Admin Profile',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMenuEditor(),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Dish'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu_outlined, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load menu items',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = _applySearch(snapshot.data ?? const []);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search dishes, categories or tags',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  '${items.length} menu items',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('No menu items found')),
                  )
                else
                  ...items.map((item) => _menuCard(item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuCard(Map<String, dynamic> item) {
    final imageUrl = _display(item['image_url'], fallback: '');
    final isAvailable = item['is_available'] != false;
    final isTrending = item['is_trending'] == true;
    final tags = ((item['tags'] as List?) ?? const []).map((tag) => tag.toString()).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.fastfood),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _display(item['name']),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '₹${item['price'] ?? 0}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(_display(item['category'])),
                    _chip(isAvailable ? 'Available' : 'Out of stock', highlighted: isAvailable),
                    if (isTrending) _chip('Trending', highlighted: true),
                    ...tags.take(3).map((tag) => _chip(tag)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleAvailability(item),
                        icon: Icon(isAvailable ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        label: Text(isAvailable ? 'Mark Out of Stock' : 'Mark Available'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleTrending(item),
                        icon: const Icon(Icons.local_fire_department_outlined),
                        label: Text(isTrending ? 'Remove Trending' : 'Set Trending'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showMenuEditor(item: item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? Colors.red.shade700 : Colors.grey.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}