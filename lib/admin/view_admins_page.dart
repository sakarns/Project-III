import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_users_page.dart';

class ViewAdminsPage extends StatefulWidget {
  const ViewAdminsPage({super.key});

  @override
  State<ViewAdminsPage> createState() => _ViewAdminsPageState();
}

class _ViewAdminsPageState extends State<ViewAdminsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<String?> _getSignedUrl(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    try {
      final normalizedPath = filePath.startsWith('avatars/')
          ? filePath
          : 'avatars/$filePath';
      final signedUrl = await supabase.storage
          .from('profile-images')
          .createSignedUrl(normalizedPath, 3600);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _loading = true);
    final data = await supabase
        .from('admin_users')
        .select('id, position, added_at, users_profile(*)');

    if (!mounted) return;

    List<Map<String, dynamic>> list = [];
    for (var admin in data) {
      final user = admin['users_profile'];
      final signed = await _getSignedUrl(user['profile_url']);
      list.add({
        'admin_id': admin['id'],
        'position': admin['position'],
        'added_at': admin['added_at'],
        'username': user['username'],
        'first_name': user['first_name'],
        'last_name': user['last_name'],
        'email': user['email'],
        'contact': user['contact'],
        'profile_url': user['profile_url'],
        'signed_profile_url': signed,
      });
    }

    setState(() {
      _admins = list;
      _loading = false;
    });
  }

  Future<void> _updatePosition(String adminId, String currentPosition) async {
    String? selected = currentPosition;
    final pos = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Position'),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          items: [
            'Founder',
            'CEO',
            'Finance ',
            'Supervisor',
            'Manager',
            'Delivery in charge',
            'Worker',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => selected = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (pos != null && pos != currentPosition) {
      await supabase
          .from('admin_users')
          .update({'position': pos})
          .eq('id', adminId);
      await _loadAdmins();
    }
  }

  Future<void> _deleteAdmin(String adminId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Admin'),
        content: const Text('Are you sure you want to remove this admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('admin_users').delete().eq('id', adminId);
    await _loadAdmins();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Admins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewUsersPage()),
              );
              await _loadAdmins();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAdmins,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _admins.isEmpty
            ? const Center(child: Text('No admins found'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  final fullName =
                      '${admin['first_name'] ?? ''} ${admin['last_name'] ?? ''}'
                          .trim();
                  final signedUrl = admin['signed_profile_url'];
                  final position = admin['position'] ?? '';
                  final addedAt = admin['added_at'] != null
                      ? DateTime.parse(admin['added_at']).toLocal()
                      : null;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundImage:
                                    signedUrl != null && signedUrl.isNotEmpty
                                    ? NetworkImage(signedUrl)
                                    : null,
                                child: signedUrl == null || signedUrl.isEmpty
                                    ? Text(
                                        admin['username'] != null &&
                                                admin['username']
                                                    .toString()
                                                    .isNotEmpty
                                            ? admin['username'][0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(fontSize: 28),
                                      )
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
                                    onPressed: () => _updatePosition(
                                      admin['admin_id'],
                                      position,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () =>
                                        _deleteAdmin(admin['admin_id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  admin['username'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(fullName),
                                const SizedBox(height: 4),
                                Text(admin['email'] ?? ''),
                                const SizedBox(height: 4),
                                Text('Position: $position'),
                                if (addedAt != null)
                                  Text(
                                    'Added: ${addedAt.day}/${addedAt.month}/${addedAt.year}',
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
      ),
    );
  }
}
