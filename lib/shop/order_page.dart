import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'order_service.dart';
import '../user/user_service.dart';
import '../user/user_session.dart';
import 'checkout_page.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  TextEditingController descriptionController = TextEditingController();
  LatLng? deliveryLocation;
  String? selectedAreaName;
  String paymentMethod = 'Cash on Delivery';
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  bool loading = true;
  bool isSubmitting = false;
  bool orderLimitReached = false;
  List<Map<String, dynamic>> orders = [];
  double grandTotal = 0;
  double totalDiscount = 0;
  final double _zoom = 13.0;
  final millLocation = UserService.millLocation();

  bool get canCheckout =>
      orders.any((o) => (o['is_checkout'] as bool? ?? false) == false);

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _checkOrderLimit();
  }

  Future<void> _checkOrderLimit() async {
    final count = await OrderService().getCheckoutCount();
    if (count >= 3) {
      setState(() => orderLimitReached = true);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => loading = true);
    try {
      orders = await OrderService().getOrders();
      grandTotal = orders.fold<double>(
        0,
        (sum, item) => sum + (item['total_price'] ?? 0),
      );
      totalDiscount = orders.fold<double>(
        0,
        (sum, item) => sum + (item['discount'] ?? 0),
      );
      if (deliveryLocation == null &&
          UserSession.latitude != null &&
          UserSession.longitude != null) {
        deliveryLocation = LatLng(
          UserSession.latitude!,
          UserSession.longitude!,
        );
      }
      _setupMarkers();
    } catch (_) {
      orders = [];
    } finally {
      setState(() => loading = false);
    }
  }

  void _setupMarkers() {
    _markers.clear();
    if (deliveryLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: deliveryLocation!,
          infoWindow: const InfoWindow(title: 'Delivery'),
        ),
      );
    }
    _markers.add(
      Marker(
        markerId: const MarkerId('mill'),
        position: millLocation,
        infoWindow: const InfoWindow(title: 'Mill'),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBounds());
    setState(() {});
  }

  void _animateToBounds() {
    if (_mapController == null || _markers.isEmpty) return;
    final positions = _markers.map((m) => m.position).toList();
    double south = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double north = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double west = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double east = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _pickDeliveryLocation() async {
    LatLng initial = deliveryLocation ?? millLocation;
    LatLng selectedPoint = initial;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> updateLocation(LatLng point) async {
              setModalState(() => selectedPoint = point);
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  point.latitude,
                  point.longitude,
                );
                if (placemarks.isNotEmpty) {
                  final area =
                      placemarks.first.locality ??
                      placemarks.first.subLocality ??
                      placemarks.first.name ??
                      'Unknown Area';
                  setState(() {
                    deliveryLocation = point;
                    selectedAreaName = area;
                    _setupMarkers();
                  });
                }
              } catch (_) {}
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Pick Delivery Location",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: selectedPoint,
                        zoom: 12.5,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: selectedPoint,
                        ),
                        Marker(
                          markerId: const MarkerId('mill'),
                          position: millLocation,
                        ),
                      },
                      onTap: updateLocation,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "Selected Area: ${selectedAreaName ?? 'None'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Confirm Location"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapSection() {
    final LatLng initialPosition = deliveryLocation ?? millLocation;
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            _animateToBounds();
          },
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: _zoom,
          ),
          markers: _markers,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Future<void> _confirmOrder() async {
    if (isSubmitting || orderLimitReached) return;
    setState(() => isSubmitting = true);
    try {
      final checkoutCount = await OrderService().getCheckoutCount();
      if (checkoutCount >= 3) {
        if (!mounted) return;
        setState(() => orderLimitReached = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order limit over, 3 times only')),
        );
        return;
      }

      final pendingOrders = orders
          .where((o) => (o['is_checkout'] as bool? ?? false) == false)
          .toList();
      if (pendingOrders.isEmpty) return;

      final totalAmount = pendingOrders.fold<double>(
        0,
        (sum, item) => sum + (item['total_price'] ?? 0),
      );
      final totalDiscount = pendingOrders.fold<double>(
        0,
        (sum, item) => sum + (item['discount'] ?? 0),
      );

      final DateTime now = DateTime.now();

      await OrderService().createCheckout(
        totalAmount: totalAmount,
        totalDiscount: totalDiscount,
        paymentMethod: paymentMethod,
        deliveryDescription: descriptionController.text.trim(),
        deliveryLat: deliveryLocation?.latitude,
        deliveryLng: deliveryLocation?.longitude,
        deliveryAddress: selectedAreaName ?? UserSession.address,
        createdAt: now,
      );

      final service = OrderService();
      final futures = pendingOrders.map((item) async {
        await service.updateOrderCheckoutStatus(
          orderId: item['id'],
          isCheckout: true,
          updatedAt: now,
        );
        await service.deleteCartItem(item['cart_id']);
      });
      await Future.wait(futures);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order checkout recorded successfully.')),
      );
      await Future.wait([
        Future(() => _loadOrders()),
      ]);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CheckoutPage()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _removeOrderItem(Map<String, dynamic> item) async {
    final orderId = item['id'] as int?;
    if (orderId != null) {
      await OrderService().deleteOrder(orderId);
      setState(() {
        orders.remove(item);
        grandTotal = orders.fold<double>(
          0,
          (sum, item) => sum + (item['total_price'] ?? 0),
        );
        totalDiscount = orders.fold<double>(
          0,
          (sum, item) => sum + (item['discount'] ?? 0),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add_check_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Quantity')),
                            DataColumn(label: Text('Price/Unit')),
                            DataColumn(label: Text('Discount')),
                            DataColumn(label: Text('Total Price')),
                            DataColumn(label: Text('Remove')),
                          ],
                          rows: orders.map((item) {
                            final productsData = item['products'];
                            Map<String, dynamic> product = {};
                            if (productsData is List &&
                                productsData.isNotEmpty) {
                              product = Map<String, dynamic>.from(
                                productsData[0],
                              );
                            } else if (productsData is Map<String, dynamic>) {
                              product = productsData;
                            }
                            return DataRow(
                              cells: [
                                DataCell(Text(product['name'] ?? '')),
                                DataCell(
                                  Text(
                                    '${item['order_quantity'] ?? 0} ${product['unit'] ?? ''}',
                                  ),
                                ),
                                DataCell(
                                  Text('Rs.${product['price_per_unit'] ?? 0}'),
                                ),
                                DataCell(Text('Rs.${item['discount'] ?? 0}')),
                                DataCell(
                                  Text('Rs.${item['total_price'] ?? 0}'),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: colors.error,
                                    ),
                                    onPressed: () => _removeOrderItem(item),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full Discount: Rs.$totalDiscount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Total Amount: Rs.$grandTotal',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text('Payment Method:'),
                          DropdownButton<String>(
                            value: paymentMethod,
                            isExpanded: true,
                            items:
                                [
                                      'Cash on Delivery',
                                      'Online Wallet',
                                      'Online Banking',
                                      'Scan QR Code',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => paymentMethod = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name: ${UserSession.firstName ?? ''} ${UserSession.lastName ?? ''}',
                          ),
                          Text('Contact: ${UserSession.contact ?? ''}'),
                          Text('Email: ${UserSession.email ?? ''}'),
                          Text('Home Address: ${UserSession.address ?? ''}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Delivery Location:\n${selectedAreaName ?? UserSession.address ?? ''}',
                                ),
                              ),
                              IconButton(
                                onPressed: _pickDeliveryLocation,
                                icon: Icon(
                                  Icons.location_on,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: ElevatedButton(
                        onPressed:
                            (!canCheckout || isSubmitting || orderLimitReached)
                            ? null
                            : _confirmOrder,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Confirm Order'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
