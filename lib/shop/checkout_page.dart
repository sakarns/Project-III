import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../user/user_service.dart';
import 'checkout_service.dart';
import 'order_tracking_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CheckoutService _service = CheckoutService();
  final List<Map<String, dynamic>> _checkouts = [];
  final Map<int, List<Map<String, dynamic>>> _ordersByCheckoutId = {};
  final LatLng _millLocation = UserService.millLocation();
  final Map<int, LatLng> _deliveryLocations = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final checkouts = await _service.fetchCheckouts();
    if (!mounted) return;
    for (int i = 0; i < checkouts.length - 1; i++) {
      checkouts[i]['next_checkout_created_at'] = DateTime.tryParse(
        checkouts[i + 1]['created_at'],
      );
    }
    _checkouts
      ..clear()
      ..addAll(checkouts);
    for (final checkout in _checkouts) {
      final id = checkout['id'] as int;
      final orders = await _service.fetchOrdersByCheckout(checkout);
      if (!mounted) return;
      _ordersByCheckoutId[id] = orders;
      final dlng = _toDouble(checkout['delivery_lng']);
      final dlat = _toDouble(checkout['delivery_lat']);
      if (dlat != null && dlng != null) {
        _deliveryLocations[id] = LatLng(dlat, dlng);
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    try {
      return double.parse(val.toString());
    } catch (_) {
      return null;
    }
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orders) {
    final rows = orders.map((o) {
      final product = (o['products'] ?? {}) as Map<String, dynamic>;
      return DataRow(
        cells: [
          DataCell(Text(product['name'] ?? 'Sample Product')),
          DataCell(
            Text('${o['order_quantity'] ?? 1} ${product['unit'] ?? 'kg'}'),
          ),
          DataCell(Text('Rs.${product['price_per_unit'] ?? 100}')),
          DataCell(Text('Rs.${o['discount'] ?? 0}')),
          DataCell(Text('Rs.${o['total_price'] ?? 100}')),
        ],
      );
    }).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text(
              'Product',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Quantity',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Unit Price',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Discount',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Total Price',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: rows.isEmpty
            ? const [
                DataRow(
                  cells: [
                    DataCell(Text('Sample Product')),
                    DataCell(Text('1 kg')),
                    DataCell(Text('Rs.100')),
                    DataCell(Text('Rs.0')),
                    DataCell(Text('Rs.100')),
                  ],
                ),
              ]
            : rows,
      ),
    );
  }

  Future<void> _requestCancel(int id) async {
    await _service.updateCheckoutStatus(id, 'cancel requested');
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cancellation request sent.')));
  }

  Future<void> _revertToPending(int id) async {
    await _service.updateCheckoutStatus(id, 'Pending');
    if (!mounted) return;
    await _loadAll();
  }

  void _openMapFullView() {
    if (!mounted) return;
    final locations = _deliveryLocations.values.toSet().toList();
    if (locations.isEmpty) {
      locations.add(_millLocation);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingPage(
          millLocation: _millLocation,
          deliveryLocations: locations,
        ),
      ),
    );
  }

  Widget _buildCheckoutCard(Map<String, dynamic> checkout, int index) {
    final orders = _ordersByCheckoutId[checkout['id']] ?? [];
    final createdAt =
        DateTime.tryParse(checkout['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat.yMd().add_jm().format(createdAt);
    final totalAmount = checkout['total_amount'] ?? 100;
    final paymentMethod = checkout['payment_method'] ?? 'Cash';
    final deliveryAddress = checkout['delivery_address'] ?? 'Sample Address';
    final orderStatus = checkout['order_status'] ?? 'Pending';
    final bool isCanceled = orderStatus == 'request for cancellation';
    final Color buttonColor = isCanceled ? Colors.blueGrey : Colors.red;
    final String buttonText = isCanceled ? 'Order Again' : 'Cancel Order';
    final VoidCallback buttonAction = isCanceled
        ? () => _revertToPending(checkout['id'])
        : () => _requestCancel(checkout['id']);
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
                Text(
                  'Checkout ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(formattedDate, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            _buildOrdersTable(orders),
            const SizedBox(height: 8),
            Text(
              'Total Amount: Rs.$totalAmount',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Payment Method: $paymentMethod'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Delivery Address:\n$deliveryAddress')),
                IconButton(
                  onPressed: _openMapFullView,
                  icon: const Icon(Icons.location_on, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order Status: $orderStatus'),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: buttonAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedCheckouts = _loading || _checkouts.isEmpty
        ? List.generate(1, (index) => <String, dynamic>{})
        : _checkouts;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkouts'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...displayedCheckouts.asMap().entries.map((entry) {
              final index = entry.key;
              final checkout = entry.value;
              return _buildCheckoutCard(checkout, index);
            }),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _openMapFullView,
                icon: const Icon(Icons.map),
                label: const Text('View Delivery Map'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
