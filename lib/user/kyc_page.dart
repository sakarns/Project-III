import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:geocoding/geocoding.dart';
import 'user_session.dart';
import 'user_service.dart';

class KYCPage extends StatefulWidget {
  final String userId;

  const KYCPage({super.key, required this.userId});

  @override
  State<KYCPage> createState() => _KYCPageState();
}

class _KYCPageState extends State<KYCPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _selectedImage;
  String? _profilePath;
  String? _signedUrl;
  bool _updating = false;

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAreaName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await UserService().loadUserProfile(userId: widget.userId);
    if (!mounted) return;
    _firstNameController.text = UserSession.firstName ?? '';
    _lastNameController.text = UserSession.lastName ?? '';
    _usernameController.text = UserSession.username ?? '';
    _emailController.text = UserSession.email ?? '';
    _dobController.text = UserSession.dob != null
        ? "${UserSession.dob!.year}-${UserSession.dob!.month.toString().padLeft(2, '0')}-${UserSession.dob!.day.toString().padLeft(2, '0')}"
        : '';
    _phoneController.text = UserSession.contact ?? '';
    _addressController.text = UserSession.address ?? '';
    _selectedLat = UserSession.latitude;
    _selectedLng = UserSession.longitude;
    _profilePath = UserSession.profileUrl;
    if (_profilePath != null && _profilePath!.isNotEmpty)
      await _loadSignedUrl(_profilePath!);
    setState(() {});
  }

  Future<void> _loadSignedUrl(String storagePath) async {
    try {
      final url = await Supabase.instance.client.storage
          .from('profile-images')
          .createSignedUrl(storagePath, 3600);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {
      if (mounted) setState(() => _signedUrl = null);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: UserSession.dob ?? DateTime(2000),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _showImagePickerOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedImage = File(picked.path);
          _signedUrl = null;
        });
      }
    }
  }

  Future<String?> _uploadProfileImage(File file) async {
    final supabase = Supabase.instance.client;
    final ext = path.extension(file.path);
    final fileName = "avatars/${widget.userId}_${const Uuid().v4()}$ext";
    await supabase.storage
        .from('profile-images')
        .upload(fileName, file, fileOptions: const FileOptions(upsert: true));
    return fileName;
  }

  Future<void> _openMapPicker() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        gmap.LatLng selectedPoint = gmap.LatLng(
          _selectedLat ?? 27.677955627828176,
          _selectedLng ?? 85.36591918919332,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> updateLocation(gmap.LatLng point) async {
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
                      "Unknown Area";
                  setState(() {
                    _selectedLat = point.latitude;
                    _selectedLng = point.longitude;
                    _selectedAreaName = area;
                    _addressController.text = area;
                  });
                }
              } catch (_) {}
            }

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Update your home location",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: gmap.GoogleMap(
                      initialCameraPosition: gmap.CameraPosition(
                        target: selectedPoint,
                        zoom: 12.5,
                      ),
                      onTap: updateLocation,
                      markers: {
                        gmap.Marker(
                          markerId: const gmap.MarkerId('selected'),
                          position: selectedPoint,
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selected Area: ${_selectedAreaName ?? 'None'}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
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

  Future<void> _updateProfile() async {
    setState(() => _updating = true);
    final supabase = Supabase.instance.client;
    try {
      String? imagePath = _profilePath;
      if (_selectedImage != null) {
        final uploaded = await _uploadProfileImage(_selectedImage!);
        if (uploaded != null) {
          imagePath = uploaded;
          _signedUrl = null;
          await _loadSignedUrl(imagePath);
        }
      }
      await supabase
          .from('users_profile')
          .update({
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'dob': _dobController.text.trim(),
            'contact': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'profile_url': imagePath,
            'latitude': _selectedLat,
            'longitude': _selectedLng,
          })
          .eq('id', widget.userId);

      await UserService().loadUserProfile(userId: widget.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating: $e")));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  InputDecoration _inputDecoration(String label, [Widget? suffixIcon]) =>
      InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: suffixIcon,
      );

  @override
  Widget build(BuildContext context) {
    final ImageProvider? displayImage = _selectedImage != null
        ? FileImage(_selectedImage!)
        : (_signedUrl != null
              ? NetworkImage(_signedUrl!)
              : (_profilePath != null && _profilePath!.startsWith('http')
                    ? NetworkImage(_profilePath!)
                    : null));

    return Scaffold(
      appBar: AppBar(title: const Text('Update KYC'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: displayImage,
                child: displayImage == null
                    ? Text(
                        UserSession.username?.isNotEmpty == true
                            ? UserSession.username![0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 40,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _firstNameController,
              decoration: _inputDecoration('First/Middle Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: _inputDecoration('Last Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: _inputDecoration('Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: _inputDecoration('Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobController,
              readOnly: true,
              decoration: _inputDecoration(
                'Date of Birth',
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: _inputDecoration('Contact Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: _inputDecoration(
                'Full Address (inside KTM Valley only)',
                IconButton(
                  icon: const Icon(Icons.location_on),
                  onPressed: _openMapPicker,
                ),
              ),
            ),
            if (_selectedAreaName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  "Selected Area: $_selectedAreaName",
                  style: const TextStyle(color: Colors.green, fontSize: 13),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updating ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _updating
                    ? const CircularProgressIndicator()
                    : const Text('Update KYC', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
