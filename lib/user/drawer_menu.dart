import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class DrawerMenu extends StatefulWidget {
  const DrawerMenu({super.key});

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> {
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isLoggedIn = supabase.auth.currentSession != null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildUserHeader(),
          _buildDrawerItem(Icons.home, "Home", '/home'),
          _buildDrawerItem(Icons.people, "Profile", '/profile'),
          _buildDrawerItem(Icons.info, "About Us", '/about'),
          const Divider(),
          _buildDrawerItem(Icons.favorite_rounded, "Favorite", '/favorite'),
          _buildDrawerItem(Icons.add_shopping_cart, "Cart", '/cart'),
          _buildDrawerItem(Icons.pending_actions, "Orders", '/order'),
          _buildDrawerItem(
            Icons.library_add_check_outlined,
            "CheckOut",
            '/checkout',
          ),
          const Divider(),
          _buildDrawerItem(Icons.message, "Messages", '/messages'),
          _buildDrawerItem(
            Icons.notification_important,
            "Notifications",
            '/notifications',
          ),
          _buildDrawerItem(Icons.settings, "Settings", '/settings'),
          const Divider(),
          if (!isLoggedIn)
            _buildDrawerItem(Icons.person_add, "Register", '/register'),
          if (!isLoggedIn) _buildDrawerItem(Icons.login, "Login", '/login'),
          if (isLoggedIn) _buildLogoutItem(context),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    final username = UserSession.username;
    final email = UserSession.email;
    final profileUrl = UserSession.profileUrl;

    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: Colors.green),
      accountName: Text(
        username?.isNotEmpty == true ? username! : "Guest",
        style: const TextStyle(fontSize: 18),
      ),
      accountEmail: Text(email ?? "guest@example.com"),
      currentAccountPictureSize: const Size.square(56),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white60,
        backgroundImage: profileUrl != null && profileUrl.isNotEmpty
            ? NetworkImage(profileUrl)
            : null,
        child: profileUrl == null || profileUrl.isEmpty
            ? Text(
                username?.isNotEmpty == true ? username![0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 30, color: Colors.blue),
              )
            : null,
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout),
      title: const Text("Logout"),
      onTap: () async {
        await Supabase.instance.client.auth.signOut();
        UserSession.clear();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      },
    );
  }
}
