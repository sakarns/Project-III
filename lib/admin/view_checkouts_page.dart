import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewCheckoutsPage extends StatefulWidget {
  final String userId;
  const ViewCheckoutsPage({super.key, required this.userId});

  @override
  State<ViewCheckoutsPage> createState() => _ViewCheckoutsPageState();
}

class _ViewCheckoutsPageState extends State<ViewCheckoutsPage> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  final List<Map<String, dynamic>> _checkouts = [];

  @override
  void initState() {
    super.initState();
    _loadCheckouts();
  }

  Future<void> _loadCheckouts() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final res = await supabase
        .from('checkout')
        .select('*')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    _checkouts
      ..clear()
      ..addAll(res.map((c) => Map<String, dynamic>.from(c)));

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _updateCheckoutStatus(Map<String, dynamic> checkout, String statusType, String value) async {
    await supabase
        .from('checkout')
        .update({statusType: value, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', checkout['id']);
    await _loadCheckouts();
  }

  Future<void> _finalizeTransaction() async {
    for (final checkout in _checkouts) {
      final checkoutId = checkout['id'];
      final orders = await supabase.from('orders').select('*').eq('checkout_id', checkoutId);

      for (final o in orders) {
        await supabase.from('order_history').insert({
          'checkout_id': checkoutId,
          'product_id': o['product_id'],
          'user_id': o['user_id'],
          'order_quantity': o['order_quantity'],
          'discount': o['discount'],
          'total_price': o['total_price'],
          'unit_price': o['unit_price'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await supabase.from('checkout_history').insert({
        'user_id': checkout['user_id'],
        'total_amount': checkout['total_amount'],
        'payment_method': checkout['payment_method'],
        'payment_status': checkout['payment_status'],
        'order_status': checkout['order_status'],
        'delivery_description': checkout['delivery_description'],
        'delivery_lat': checkout['delivery_lat'],
        'delivery_lng': checkout['delivery_lng'],
        'delivery_address': checkout['delivery_address'],
        'total_discount': checkout['total_discount'],
        'created_at': checkout['created_at'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      await supabase.from('orders').delete().eq('checkout_id', checkoutId);
      await supabase.from('checkout').delete().eq('id', checkoutId);
    }

    await _loadCheckouts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('All transactions finalized and moved to history!'),
    ));
  }

  Widget _buildSection(String label, String value, List<Widget> buttons) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ],
      ),
      if (buttons.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: buttons),
      ],
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildCheckoutCard(Map<String, dynamic> checkout) {
    final createdAt = DateTime.tryParse(checkout['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat.yMd().add_jm().format(createdAt);
    final isCancelled = checkout['order_status'].toString().toLowerCase() == 'cancelled';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Checkout #${checkout['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Created: $formattedDate', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const Divider(height: 20, thickness: 1),

          _buildSection(
            'Payment Method',
            checkout['payment_method'] ?? 'Cash',
            [
              ElevatedButton(
                onPressed: isCancelled ? null : () => _updateCheckoutStatus(checkout, 'payment_status', 'Payment Successful'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(130, 36)),
                child: const Text('Payment Successful'),
              ),
            ],
          ),

          _buildSection(
            'Payment Status',
            checkout['payment_status'] ?? 'Pending',
            [],
          ),

          _buildSection(
            'Delivery Status',
            checkout['order_status'] ?? 'Pending',
            [
              ElevatedButton(
                onPressed: isCancelled ? null : () => _updateCheckoutStatus(checkout, 'order_status', 'Ready to Deliver'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
                child: const Text('Ready to Deliver'),
              ),
              ElevatedButton(
                onPressed: isCancelled ? null : () => _updateCheckoutStatus(checkout, 'order_status', 'Delivery Successful'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(140, 36)),
                child: const Text('Delivery Successful'),
              ),
            ],
          ),

          _buildSection(
            'Order Status',
            checkout['order_status'] ?? 'Pending',
            [
              ElevatedButton(
                onPressed: isCancelled ? null : () => _updateCheckoutStatus(checkout, 'order_status', 'Transaction Successful'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(100, 36)),
                child: const Text('Success'),
              ),
              ElevatedButton(
                onPressed: isCancelled ? null : () => _updateCheckoutStatus(checkout, 'order_status', 'Cancelled'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(100, 36)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Checkouts')),
      body: RefreshIndicator(
        onRefresh: _loadCheckouts,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _checkouts.isEmpty
            ? const Center(child: Text('No checkouts available.'))
            : Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _checkouts.length,
                itemBuilder: (context, index) => _buildCheckoutCard(_checkouts[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _checkouts.isEmpty ? null : _finalizeTransaction,
                icon: const Icon(Icons.check_circle),
                label: const Text('Finalize All Transactions'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
