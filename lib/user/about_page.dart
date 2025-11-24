import 'package:flutter/material.dart';
import 'package:minimills/user/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Marker _marker;

  final millLocation = UserService.millLocation();

  @override
  void initState() {
    super.initState();
    _marker = Marker(
      markerId: const MarkerId('minimill_location'),
      position: millLocation,
      infoWindow: const InfoWindow(title: "Mini~Mills"),
    );
  }

  void _onMapCreated(GoogleMapController controller) {}

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mill logo
            CircleAvatar(
              radius: 60,
              backgroundImage: const AssetImage(
                'assets/images/minimills_logo.png',
              ),
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 16),

            // Mill info
            const Text(
              'Mini~Mills',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mill Type: Rice & Oil Mill',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              'Owner: Sakar Pd. Mainali',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              'Location: Kathmandu, Nepal',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              'Operating Hours: 9:00 AM – 5:00 PM',
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              'Registered ID: 12345678',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Contact icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Facebook
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue[800],
                  child: IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.facebookF,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _launchUrl('https://www.facebook.com/yourpage');
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // WhatsApp
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green[700],
                  child: IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _launchUrl('https://wa.me/yourwhatsappnumber');
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Email
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red[600],
                  child: IconButton(
                    icon: const Icon(Icons.email, color: Colors.white),
                    onPressed: () {
                      _launchUrl('mailto:yourmail@example.com');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Map Integration
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: millLocation,
                    zoom: 15,
                  ),
                  markers: {_marker},
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
