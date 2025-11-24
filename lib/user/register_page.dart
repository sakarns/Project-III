import 'package:flutter/material.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:geocoding/geocoding.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _touchedFirst = false;
  bool _touchedLast = false;
  bool _touchedUsername = false;
  bool _touchedEmail = false;
  bool _touchedDob = false;
  bool _touchedPass = false;
  bool _touchedConfirm = false;
  bool _touchedPhone = false;
  bool _touchedAddress = false;

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAreaName;

  gmap.GoogleMapController? _mapController;

  static final gmap.LatLngBounds ktmValleyBounds = gmap.LatLngBounds(
    southwest: const gmap.LatLng(27.540259574704752, 85.16557446990555),
    northeast: const gmap.LatLng(27.834541584490218, 85.51381684139433),
  );

  bool get _isFirstNameValid => _firstNameController.text.trim().isNotEmpty;

  bool get _isLastNameValid => _lastNameController.text.trim().isNotEmpty;

  bool get _isUsernameValid => RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*]).{6,}$',
  ).hasMatch(_usernameController.text.trim());

  bool get _isEmailValid =>
      _emailController.text.trim().contains('@') &&
      _emailController.text.trim().contains('.');

  bool get _isDobValid => _dobController.text.trim().isNotEmpty;

  bool get _isPasswordValid => RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*]).{6,}$',
  ).hasMatch(_passwordController.text.trim());

  bool get _isConfirmPasswordValid =>
      _confirmPasswordController.text == _passwordController.text;

  bool get _isPhoneValid =>
      RegExp(r'^9[6-8]\d{8}$').hasMatch(_phoneController.text.trim());

  bool get _isAddressValid => _addressController.text.trim().isNotEmpty;

  bool get _isValid =>
      _isFirstNameValid &&
      _isLastNameValid &&
      _isUsernameValid &&
      _isEmailValid &&
      _isDobValid &&
      _isPasswordValid &&
      _isConfirmPasswordValid &&
      _isPhoneValid &&
      _isAddressValid;

  Future<void> _selectDate() async {
    final picked = await showAdaptiveDatePicker(
      context: context,
      initialDate: NepaliDateTime.now(),
      firstDate: NepaliDateTime(2000),
      lastDate: NepaliDateTime.now(),
    );
    if (picked != null) {
      _dobController.text = NepaliDateFormat("yyyy-MM-dd").format(picked);
      setState(() => _touchedDob = true);
    }
  }

  Future<bool> _isDuplicateField(String field, String value) async {
    final data = await Supabase.instance.client
        .from('users_profile')
        .select('id')
        .eq(field, value)
        .maybeSingle();
    return data != null;
  }

  Future<void> _registerUser() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final contact = _phoneController.text.trim();

    if (await _isDuplicateField('username', username) ||
        await _isDuplicateField('email', email) ||
        await _isDuplicateField('contact', contact)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Username, email or contact already used'),
        ),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Registration failed')),
        );
        return;
      }

      await Supabase.instance.client.from('users_profile').insert({
        'id': userId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'username': username,
        'email': email,
        'dob': _dobController.text.trim(),
        'contact': contact,
        'address': _addressController.text.trim(),
        'latitude': _selectedLat,
        'longitude': _selectedLng,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Registered successfully')),
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    }
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
          _selectedLat ?? 27.7172,
          _selectedLng ?? 85.3240,
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
                    _touchedAddress = true;
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
                    "Select your home location",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: gmap.GoogleMap(
                      initialCameraPosition: gmap.CameraPosition(
                        target: gmap.LatLng(
                          (ktmValleyBounds.northeast.latitude +
                                  ktmValleyBounds.southwest.latitude) /
                              2,
                          (ktmValleyBounds.northeast.longitude +
                                  ktmValleyBounds.southwest.longitude) /
                              2,
                        ),
                        zoom: 12.5,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        Future.delayed(const Duration(milliseconds: 200), () {
                          controller.animateCamera(
                            gmap.CameraUpdate.newLatLngBounds(
                              ktmValleyBounds,
                              40,
                            ),
                          );
                        });
                      },
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      minMaxZoomPreference: const gmap.MinMaxZoomPreference(
                        10.0,
                        28.0,
                      ),
                      cameraTargetBounds: gmap.CameraTargetBounds(
                        ktmValleyBounds,
                      ),
                      onCameraMove: (position) {
                        double clampedLat = position.target.latitude.clamp(
                          ktmValleyBounds.southwest.latitude,
                          ktmValleyBounds.northeast.latitude,
                        );
                        double clampedLng = position.target.longitude.clamp(
                          ktmValleyBounds.southwest.longitude,
                          ktmValleyBounds.northeast.longitude,
                        );
                        if (clampedLat != position.target.latitude ||
                            clampedLng != position.target.longitude) {
                          _mapController?.moveCamera(
                            gmap.CameraUpdate.newLatLng(
                              gmap.LatLng(clampedLat, clampedLng),
                            ),
                          );
                        }
                      },
                      onTap: (point) => updateLocation(point),
                      markers: {
                        gmap.Marker(
                          markerId: const gmap.MarkerId('selected'),
                          position: selectedPoint,
                          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
                            gmap.BitmapDescriptor.hueRed,
                          ),
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

  InputDecoration _inputDecoration(String label, [Widget? suffixIcon]) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _withError({
    required TextField field,
    required bool touched,
    required bool valid,
    required String error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        if (touched && !valid)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(
                "Register",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withAlpha((0.12 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _withError(
                      field: TextField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration('First/Middle Name'),
                        onChanged: (_) => setState(() => _touchedFirst = true),
                      ),
                      touched: _touchedFirst,
                      valid: _isFirstNameValid,
                      error: 'Required',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration('Last Name'),
                        onChanged: (_) => setState(() => _touchedLast = true),
                      ),
                      touched: _touchedLast,
                      valid: _isLastNameValid,
                      error: 'Required',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _usernameController,
                        decoration: _inputDecoration('Username'),
                        onChanged: (_) =>
                            setState(() => _touchedUsername = true),
                      ),
                      touched: _touchedUsername,
                      valid: _isUsernameValid,
                      error: 'Must contain upper, lower, digit & special char',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('Email'),
                        onChanged: (_) => setState(() => _touchedEmail = true),
                      ),
                      touched: _touchedEmail,
                      valid: _isEmailValid,
                      error: 'Invalid email',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _dobController,
                        keyboardType: TextInputType.datetime,
                        decoration: _inputDecoration(
                          'Date of Birth',
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectDate,
                          ),
                        ),
                        onChanged: (_) => setState(() => _touchedDob = true),
                      ),
                      touched: _touchedDob,
                      valid: _isDobValid,
                      error: 'Required',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          'Password',
                          IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() => _touchedPass = true),
                      ),
                      touched: _touchedPass,
                      valid: _isPasswordValid,
                      error: 'Weak password',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: _inputDecoration(
                          'Confirm Password',
                          IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        onChanged: (_) =>
                            setState(() => _touchedConfirm = true),
                      ),
                      touched: _touchedConfirm,
                      valid: _isConfirmPasswordValid,
                      error: 'Password mismatch',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration('Contact Number'),
                        onChanged: (_) => setState(() => _touchedPhone = true),
                      ),
                      touched: _touchedPhone,
                      valid: _isPhoneValid,
                      error: 'Invalid number',
                    ),
                    const SizedBox(height: 12),
                    _withError(
                      field: TextField(
                        controller: _addressController,
                        decoration: _inputDecoration(
                          'Full Address (inside KTM Valley only)',
                          IconButton(
                            icon: const Icon(Icons.location_on),
                            onPressed: _openMapPicker,
                          ),
                        ),
                        onChanged: (_) =>
                            setState(() => _touchedAddress = true),
                      ),
                      touched: _touchedAddress,
                      valid: _isAddressValid,
                      error: 'Required',
                    ),
                    if (_selectedAreaName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          "Selected Area: $_selectedAreaName",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isValid ? _registerUser : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account?",
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      "Login Here",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
