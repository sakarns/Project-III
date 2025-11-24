class ProductSession {
  static List<Map<String, dynamic>> categories = [];
  static List<Map<String, dynamic>> products = [];

  static void clear() {
    categories = [];
    products = [];
  }
}
