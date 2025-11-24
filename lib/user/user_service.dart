import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class UserService {
  final supabase = Supabase.instance.client;

  Future<void> loadUserProfile({String? userId}) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null && userId == null) return;

    final fetchId = userId ?? currentUser!.id;
    final response = await supabase
        .from('users_profile')
        .select()
        .eq('id', fetchId)
        .maybeSingle();

    if (response == null) return;

    UserSession.userId = fetchId;
    UserSession.email = currentUser?.email;
    UserSession.username = response['username'];
    UserSession.firstName = response['first_name'];
    UserSession.lastName = response['last_name'];
    UserSession.contact = response['contact'];
    UserSession.address = response['address'];

    final imagePath = response['profile_url'];
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final normalizedPath = imagePath.startsWith('avatars/')
            ? imagePath
            : 'avatars/$imagePath';
        final signedUrl = await supabase.storage
            .from('profile-images')
            .createSignedUrl(normalizedPath, 3600);
        UserSession.profileUrl = signedUrl;
      } catch (_) {
        UserSession.profileUrl = null;
      }
    } else {
      UserSession.profileUrl = null;
    }

    UserSession.latitude = response['latitude'] != null
        ? double.tryParse(response['latitude'].toString())
        : null;
    UserSession.longitude = response['longitude'] != null
        ? double.tryParse(response['longitude'].toString())
        : null;

    if (response['dob'] != null) {
      try {
        UserSession.dob = DateTime.parse(response['dob']);
      } catch (_) {
        UserSession.dob = null;
      }
    }
  }

  static LatLng millLocation() {
    return const LatLng(27.677951747746903, 85.36581695562414);
  }
}
