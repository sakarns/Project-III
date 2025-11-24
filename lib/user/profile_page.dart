import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'kyc_page.dart';
import 'user_service.dart';
import 'user_session.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? username;
  String? email;
  String? firstName;
  String? lastName;
  DateTime? dob;
  String? contact;
  String? address;
  String? profileUrl;
  double? latitude;
  double? longitude;

  bool _loading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  double _zoom = 13.0;
  int _mapKey = 0;

  final _millLocation = UserService.millLocation();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    await UserService().loadUserProfile(userId: widget.userId);
    if (!mounted) return;

    setState(() {
      username = UserSession.username;
      email = UserSession.email;
      firstName = UserSession.firstName;
      lastName = UserSession.lastName;
      dob = UserSession.dob;
      contact = UserSession.contact;
      address = UserSession.address;
      profileUrl = UserSession.profileUrl;
      latitude = UserSession.latitude;
      longitude = UserSession.longitude;
      _loading = false;
      _mapKey++;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      _setupMarkers();
    });
  }

  void _setupMarkers() {
    if (!mounted) return;

    _markers.clear();

    final userPosition = (latitude != null && longitude != null)
        ? LatLng(latitude!, longitude!)
        : _millLocation;

    _markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: userPosition,
        infoWindow: InfoWindow(
          title: 'User Location',
          snippet: address ?? 'No address available',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('mill'),
        position: _millLocation,
        infoWindow: const InfoWindow(title: 'Mill Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToBounds();
    });

    setState(() {});
  }

  void _animateToBounds() {
    if (_mapController == null) return;

    final userPosition = (latitude != null && longitude != null)
        ? LatLng(latitude!, longitude!)
        : _millLocation;

    final bounds = LatLngBounds(
      southwest: LatLng(
        userPosition.latitude < _millLocation.latitude
            ? userPosition.latitude
            : _millLocation.latitude,
        userPosition.longitude < _millLocation.longitude
            ? userPosition.longitude
            : _millLocation.longitude,
      ),
      northeast: LatLng(
        userPosition.latitude > _millLocation.latitude
            ? userPosition.latitude
            : _millLocation.latitude,
        userPosition.longitude > _millLocation.longitude
            ? userPosition.longitude
            : _millLocation.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
  }

  Widget buildProfileRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(ThemeData theme) {
    final LatLng initialPosition = (latitude != null && longitude != null)
        ? LatLng(latitude!, longitude!)
        : _millLocation;

    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              key: ValueKey(_mapKey),
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
              compassEnabled: true,
              mapType: MapType.normal,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  onPressed: () {
                    _zoom += 1;
                    _mapController?.animateCamera(CameraUpdate.zoomTo(_zoom));
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  onPressed: () {
                    _zoom -= 1;
                    _mapController?.animateCamera(CameraUpdate.zoomTo(_zoom));
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          await _loadUserData();
        },
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage:
                          (profileUrl != null && profileUrl!.isNotEmpty)
                          ? NetworkImage(profileUrl!)
                          : null,
                      child: (profileUrl == null || profileUrl!.isEmpty)
                          ? Text(
                              username?.isNotEmpty == true
                                  ? username![0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 40,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      username ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email ?? 'No email',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        children: [
                          if (username != null)
                            buildProfileRow('Username', username!, theme),
                          if (firstName != null || lastName != null)
                            buildProfileRow(
                              'Full Name',
                              '${firstName ?? ''} ${lastName ?? ''}'.trim(),
                              theme,
                            ),
                          if (dob != null)
                            buildProfileRow(
                              'Date of Birth',
                              '${dob!.year}/${dob!.month.toString().padLeft(2, '0')}/${dob!.day.toString().padLeft(2, '0')}',
                              theme,
                            ),
                          if (address != null)
                            buildProfileRow('Address', address!, theme),
                          if (contact != null)
                            buildProfileRow('Contact', contact!, theme),
                          if (email != null)
                            buildProfileRow('Email', email!, theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMapSection(theme),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KYCPage(
                                userId: widget.userId ?? UserSession.userId!,
                              ),
                            ),
                          );
                          await _loadUserData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
