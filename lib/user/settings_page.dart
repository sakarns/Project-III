import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../settings/change_password.dart';
import '../settings/theme_selector.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showModal(BuildContext context, Widget content) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) =>
          Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isLoggedIn = supabase.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isLoggedIn) ...[
            const Text(
              "Account",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: const Text("Profile Info"),
              leading: const Icon(Icons.person_outline),
              onTap: () => _showModal(context, const Text("Edit Profile Info")),
            ),
            ListTile(
              title: const Text("Change Password"),
              leading: const Icon(Icons.lock_outline),
              onTap: () => _showModal(context, const ChangePassword()),
            ),
            ListTile(
              title: const Text("Saved Addresses"),
              leading: const Icon(Icons.location_on_outlined),
              onTap: () => _showModal(context, const Text("Manage Addresses")),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            "Preferences",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text("Theme"),
            leading: const Icon(Icons.color_lens_outlined),
            onTap: () => _showModal(context, const ThemeSelector()),
          ),
          ListTile(
            title: const Text("Notifications"),
            leading: const Icon(Icons.notifications_outlined),
            onTap: () =>
                _showModal(context, const Text("Toggle Notification Options")),
          ),
          ListTile(
            title: const Text("Language"),
            leading: const Icon(Icons.language),
            onTap: () =>
                _showModal(context, const Text("Select Language Options")),
          ),

          const SizedBox(height: 24),
          const Text(
            "Order & Delivery",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text("Order History"),
            leading: const Icon(Icons.history),
            onTap: () => _showModal(context, const Text("Show Order History")),
          ),
          ListTile(
            title: const Text("Delivery Preferences"),
            leading: const Icon(Icons.delivery_dining),
            onTap: () =>
                _showModal(context, const Text("Set Delivery Preferences")),
          ),
          ListTile(
            title: const Text("Payment Methods"),
            leading: const Icon(Icons.payment_outlined),
            onTap: () =>
                _showModal(context, const Text("Manage Payment Methods")),
          ),

          const SizedBox(height: 24),
          const Text(
            "Support",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text("FAQs"),
            leading: const Icon(Icons.help_outline),
            onTap: () => _showModal(context, const Text("FAQs Section")),
          ),
          ListTile(
            title: const Text("Contact Us"),
            leading: const Icon(Icons.support_agent),
            onTap: () => _showModal(
              context,
              const Text("Support Form / Contact Options"),
            ),
          ),
          ListTile(
            title: const Text("Terms & Conditions"),
            leading: const Icon(Icons.description_outlined),
            onTap: () =>
                _showModal(context, const Text("Show Terms & Conditions")),
          ),
        ],
      ),
    );
  }
}
