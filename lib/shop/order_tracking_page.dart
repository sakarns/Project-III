import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class OrderTrackingPage extends StatefulWidget {
  final LatLng millLocation;
  final List<LatLng> deliveryLocations;

  const OrderTrackingPage({
    super.key,
    required this.millLocation,
    required this.deliveryLocations,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _calculateOptimizedRoute();
  }

  void _setupMarkers() {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('mill'),
        position: widget.millLocation,
        infoWindow: const InfoWindow(title: 'Mill'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    for (int i = 0; i < widget.deliveryLocations.length; i++) {
      final loc = widget.deliveryLocations[i];
      _markers.add(
        Marker(
          markerId: MarkerId('delivery_$i'),
          position: loc,
          infoWindow: InfoWindow(title: 'Delivery ${i + 1}'),
        ),
      );
    }
  }

  double _haversine(LatLng a, LatLng b) {
    const R = 6371; // km
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    return 2 * R * atan2(sqrt(h), sqrt(1 - h));
  }

  List<LatLng> _dijkstra(List<LatLng> points) {
    if (points.isEmpty) return points;
    final unvisited = List<LatLng>.from(points);
    final ordered = <LatLng>[];
    var current = widget.millLocation;

    while (unvisited.isNotEmpty) {
      var nearest = unvisited.first;
      var minDist = _haversine(current, nearest);

      for (var p in unvisited) {
        final d = _haversine(current, p);
        if (d < minDist) {
          nearest = p;
          minDist = d;
        }
      }

      ordered.add(nearest);
      unvisited.remove(nearest);
      current = nearest;
    }

    return ordered;
  }

  double _aStarHeuristic(LatLng a, LatLng b) => _haversine(a, b);

  Future<void> _calculateOptimizedRoute() async {
    if (widget.deliveryLocations.isEmpty) return;

    final optimized = _dijkstra(widget.deliveryLocations);
    final end = optimized.last;
    final estimate = _aStarHeuristic(widget.millLocation, end);

    await _drawRoute(optimized, estimate);
  }

  Future<void> _drawRoute(List<LatLng> orderedPoints, double estimate) async {
    if (orderedPoints.isEmpty) return;

    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final origin = widget.millLocation;
    final destination = orderedPoints.last;

    final waypoints = orderedPoints.length > 1
        ? orderedPoints
        .sublist(0, orderedPoints.length - 1)
        .map((loc) => '${loc.latitude},${loc.longitude}')
        .join('|')
        : '';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}&mode=driving&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          final points = _decodePolyline(encodedPolyline);

          if (mounted) {
            setState(() {
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  width: 5,
                  color: Colors.blue,
                  geodesic: true,
                ),
              );
            });
          }
        }
      }
    } catch (_) {}
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.deliveryLocations.isNotEmpty
        ? widget.deliveryLocations.first
        : widget.millLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 12),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) => mapController = controller,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }
}
