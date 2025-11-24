import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:minimills/admin/delivery_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewDeliveryPage extends StatefulWidget {

  const ViewDeliveryPage({super.key});
  LatLng get millLocation => OrderService.millLocation();

  @override
  State<ViewDeliveryPage> createState() => _ViewDeliveryPageState();
}

class _ViewDeliveryPageState extends State<ViewDeliveryPage> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final supabase = Supabase.instance.client;

  List<Node> deliveryNodes = [];
  Graph deliveryGraph = Graph();

  @override
  void initState() {
    super.initState();
    _loadDeliveryLocations();
  }

  /// Step 1: Fetch deliveries from Supabase (up to 3 pending)
  Future<void> _loadDeliveryLocations() async {
    final List<dynamic> rows = await supabase
        .from('checkout')
        .select('id, delivery_lat, delivery_lng, delivery_address')
        .eq('order_status', 'Pending')
        .order('created_at', ascending: true)
        .limit(3);

    if (rows.isEmpty) return;

    List<Map<String, dynamic>> deliveries = [];
    for (var row in rows) {
      if (row['delivery_lat'] != null && row['delivery_lng'] != null) {
        deliveries.add({
          'id': row['id'],
          'lat': row['delivery_lat'],
          'lng': row['delivery_lng'],
          'address': row['delivery_address'],
        });
      }
    }

    deliveries = _mergeSameLocations(deliveries);
    deliveryNodes = deliveries
        .map((d) => Node(d['id'].toString(), d['lat'], d['lng'], d['address']))
        .toList();

    _buildGraph();
    _setupMapData();
  }

  /// Step 2: Merge duplicate coordinates
  List<Map<String, dynamic>> _mergeSameLocations(List<Map<String, dynamic>> locations) {
    Map<String, Map<String, dynamic>> merged = {};
    for (var loc in locations) {
      String key = '${loc['lat']}_${loc['lng']}';
      if (!merged.containsKey(key)) {
        merged[key] = loc;
      } else {
        merged[key]?['id'] = '${merged[key]?['id']},${loc['id']}';
      }
    }
    return merged.values.toList();
  }

  /// Step 3: Build graph for shortest path (future Dijkstra/A*)
  void _buildGraph() {
    deliveryGraph = Graph();
    Node millNode = Node('mill', widget.millLocation.latitude, widget.millLocation.longitude, 'Mill');

    // Add edges between mill and deliveries
    for (var node in deliveryNodes) {
      deliveryGraph.addEdge(millNode, node);
    }

    // Optionally, connect deliveries to each other for multi-stop routing
    for (int i = 0; i < deliveryNodes.length; i++) {
      for (int j = i + 1; j < deliveryNodes.length; j++) {
        deliveryGraph.addEdge(deliveryNodes[i], deliveryNodes[j]);
      }
    }
  }

  /// Step 4: Setup Google Map markers and polylines
  void _setupMapData() {
    _markers.clear();
    _polylines.clear();

    // Mill marker
    _markers.add(Marker(
      markerId: const MarkerId('mill'),
      position: widget.millLocation,
      infoWindow: const InfoWindow(title: 'Mill'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));

    // Delivery markers and routes
    for (var node in deliveryNodes) {
      LatLng loc = LatLng(node.lat, node.lng);
      _markers.add(Marker(
        markerId: MarkerId(node.id),
        position: loc,
        infoWindow: InfoWindow(title: node.address),
      ));

      // Polyline: mill → delivery
      _polylines.add(Polyline(
        polylineId: PolylineId('route_${node.id}'),
        points: [widget.millLocation, loc],
        width: 5,
        color: Colors.blue,
      ));
    }

    setState(() {});
  }

  /// Haversine distance in meters
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _estimateTime(double distanceMeters) {
    double speed = 10; // m/s ~36 km/h
    double timeSec = distanceMeters / speed;
    return '${(timeSec / 60).ceil()} min';
  }

  @override
  Widget build(BuildContext context) {
    LatLng center = widget.millLocation;
    if (deliveryNodes.isNotEmpty) {
      center = LatLng(deliveryNodes.first.lat, deliveryNodes.first.lng);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 12),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => mapController = controller,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
          ),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Delivery Summary', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...deliveryNodes.map((node) {
                    double distance = _haversineDistance(
                        widget.millLocation.latitude,
                        widget.millLocation.longitude,
                        node.lat,
                        node.lng);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(node.address)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formatDistance(distance)),
                              Text(_estimateTime(distance),
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Node class representing delivery point
class Node {
  final String id;
  final double lat;
  final double lng;
  final String address;
  Node(this.id, this.lat, this.lng, this.address);
}

/// Graph class with edges for Dijkstra / A*
class Graph {
  final Map<String, Map<String, double>> edges = {};

  void addEdge(Node a, Node b) {
    double distance = haversineDistance(a.lat, a.lng, b.lat, b.lng);
    edges.putIfAbsent(a.id, () => {})[b.id] = distance;
    edges.putIfAbsent(b.id, () => {})[a.id] = distance;
  }

  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
