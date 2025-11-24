import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_admins_page.dart';
import '../user/kyc_page.dart';
import '../user/register_page.dart';
import '../user/profile_page.dart';

class ViewUsersPage extends StatefulWidget {
  const ViewUsersPage({super.key});

  @override
  State<ViewUsersPage> createState() => _ViewUsersPageState();
}

class _ViewUsersPageState extends State<ViewUsersPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
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

  Future<bool> _isAdmin(String userId) async {
    final res = await supabase
        .from('admin_users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  Future<void> _addAdmin(String userId, String position) async {
    await supabase.from('admin_users').insert({
      'user_id': userId,
      'position': position,
    });
  }

  Future<void> _removeAdmin(String userId) async {
    await supabase.from('admin_users').delete().eq('user_id', userId);
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final data = await supabase.from('users_profile').select();
    if (!mounted) return;

    List<Map<String, dynamic>> list = [];
    for (var user in data) {
      final path = user['profile_url'];
      final signed = await _getSignedUrl(path);
      final isAdmin = await _isAdmin(user['id']);
      list.add({...user, 'signed_profile_url': signed, 'is_admin': isAdmin});
    }

    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('users_profile').delete().eq('id', id);
    await _loadUsers();
  }

  void _showUserActions(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] == true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user['username'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit User'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KYCPage(userId: user['id']),
                    ),
                  );
                  await _loadUsers();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(isAdmin ? Icons.remove_circle : Icons.add_circle),
                title: Text(isAdmin ? 'Remove as Admin' : 'Add as Admin'),
                onTap: () async {
                  Navigator.pop(context);
                  if (isAdmin) {
                    await _removeAdmin(user['id']);
                  } else {
                    final pos = await _choosePosition();
                    if (pos != null) await _addAdmin(user['id'], pos);
                  }
                  await _loadUsers();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _choosePosition() async {
    String? selected;
    return await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Choose Position'),
          content: DropdownButtonFormField<String>(
            items: [
              'Founder',
              'CEO',
              'Manager',
              'Supervisor',
              'Delivery in charge',
              'Finance',
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewAdminsPage()),
              );
              await _loadUsers();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              );
              await _loadUsers();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
            ? const Center(child: Text('No users found'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final fullName =
                      '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                          .trim();
                  final signedUrl = user['signed_profile_url'];
                  final address = user['address'] ?? '';
                  final contact = user['contact'] ?? '';

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
                                        user['username'] != null &&
                                                user['username']
                                                    .toString()
                                                    .isNotEmpty
                                            ? user['username'][0].toUpperCase()
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
                                    onPressed: () => _showUserActions(user),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _deleteUser(user['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfilePage(userId: user['id']),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['username'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(fullName),
                                  const SizedBox(height: 4),
                                  Text(user['email'] ?? ''),
                                  const SizedBox(height: 4),
                                  Text('Contact: $contact'),
                                  const SizedBox(height: 4),
                                  Text(address),
                                ],
                              ),
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
