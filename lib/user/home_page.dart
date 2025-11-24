import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shop/home_content.dart';
import '../shop/shop_page.dart';
import 'profile_page.dart';
import 'drawer_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  int currentIndex = 0;
  bool isAdmin = false;
  bool loadingAdmin = true;

  late List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [const HomeContent(), const ShopPage(), const ProfilePage()];
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isAdmin = false;
        loadingAdmin = false;
      });
      return;
    }

    final res = await supabase
        .from('admin_users')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      isAdmin = res != null;
      loadingAdmin = false;
    });
  }

  void _openAdmin() {
    Navigator.pushNamed(context, '/admin');
  }

  void _openNotifications() {
    Navigator.pushNamed(context, '/notifications');
  }

  void _openSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _openFavorite() {
    Navigator.pushNamed(context, '/favorite');
  }

  void _openCart() {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini~Mills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: _openNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _openFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _openCart,
          ),
          if (!loadingAdmin && isAdmin)
            IconButton(icon: const Icon(Icons.person), onPressed: _openAdmin),
        ],
      ),
      drawer: const DrawerMenu(),
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        fixedColor: Colors.green,
        items: const [
          BottomNavigationBarItem(label: "Home", icon: Icon(Icons.home)),
          BottomNavigationBarItem(
            label: "Shop",
            icon: Icon(Icons.shopping_bag),
          ),
          BottomNavigationBarItem(
            label: "Profile",
            icon: Icon(Icons.account_circle),
          ),
        ],
        onTap: (int index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
