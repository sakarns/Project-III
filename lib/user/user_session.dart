class UserSession {
  static String? userId;
  static String? username;
  static String? email;
  static String? firstName;
  static String? lastName;
  static DateTime? dob;
  static String? contact;
  static String? address;
  static String? profileUrl;
  static double? latitude;
  static double? longitude;

  static void clear() {
    userId = null;
    username = null;
    email = null;
    firstName = null;
    lastName = null;
    dob = null;
    contact = null;
    address = null;
    profileUrl = null;
    latitude = null;
    longitude = null;
  }
}
