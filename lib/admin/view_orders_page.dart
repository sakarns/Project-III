import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'view_checkouts_page.dart';

class ViewOrdersPage extends StatefulWidget {
  const ViewOrdersPage({super.key});

  @override
  State<ViewOrdersPage> createState() => _ViewOrdersPageState();
}

class _ViewOrdersPageState extends State<ViewOrdersPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  final Map<String, List<Map<String, dynamic>>> _ordersByUser = {};
  final Map<String, Map<String, dynamic>> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final ordersRes = await supabase
        .from('orders')
        .select('*, products(*)')
        .eq('is_checkout', true)
        .order('updated_at', ascending: true);

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Set<String> userIds = {};

    for (final row in ordersRes) {
      final uid = row['user_id'];
      userIds.add(uid);
      grouped.putIfAbsent(uid, () => []);
      grouped[uid]!.add(row);
    }

    if (userIds.isNotEmpty) {
      final usersRes = await supabase
          .from('users_profile')
          .select('id, first_name, last_name, username, email, contact, address')
          .inFilter('id', userIds.toList());

      final Map<String, Map<String, dynamic>> usersMap = {};
      for (final u in usersRes) {
        usersMap[u['id']] = Map<String, dynamic>.from(u);
      }
      _userInfo
        ..clear()
        ..addAll(usersMap);
    }

    _ordersByUser
      ..clear()
      ..addAll(grouped);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orders) {
    final rows = orders.map((o) {
      final p = (o['products'] ?? {}) as Map<String, dynamic>;
      return DataRow(cells: [
        DataCell(Text(p['name'] ?? 'Sample Product')),
        DataCell(Text('${o['order_quantity'] ?? 1} ${p['unit'] ?? 'kg'}')),
        DataCell(Text('Rs.${p['price_per_unit'] ?? 100}')),
        DataCell(Text('Rs.${o['discount'] ?? 0}')),
        DataCell(Text('Rs.${o['total_price'] ?? 100}')),
      ]);
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Discount', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total Price', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: rows.isEmpty
            ? const [
          DataRow(cells: [
            DataCell(Text('Sample Product')),
            DataCell(Text('1 kg')),
            DataCell(Text('Rs.100')),
            DataCell(Text('Rs.0')),
            DataCell(Text('Rs.100')),
          ])
        ]
            : rows,
      ),
    );
  }

  Widget _buildUserSection(String userId, List<Map<String, dynamic>> orders, int index) {
    final firstOrder = orders.isNotEmpty ? orders.first : null;
    final date = firstOrder != null
        ? DateTime.tryParse(firstOrder['updated_at'] ?? '')
        : DateTime.now();
    final formatted = DateFormat.yMd().add_jm().format(date!);

    final user = _userInfo[userId] ?? {};
    final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}';
    final username = user['username'] ?? 'Unknown';
    final email = user['email'] ?? 'Unknown';
    final contact = user['contact'] ?? 'Unknown';
    final address = user['address'] ?? 'Unknown';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('User ${index + 1}: $fullName', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(formatted, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Username: $username'),
            Text('Email: $email'),
            Text('Contact: $contact'),
            Text('Home Address: $address'),
            const SizedBox(height: 8),
            _buildOrdersTable(orders),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewCheckoutsPage(userId: userId),
                    ),
                  );
                },
                child: const Text('View Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _ordersByUser.entries.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Orders List'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_loading || entries.isEmpty)
              _buildUserSection('Sample User', [], 0)
            else
              ...entries.asMap().entries.map((e) {
                final idx = e.key;
                final uid = e.value.key;
                final orders = e.value.value;
                return _buildUserSection(uid, orders, idx);
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
