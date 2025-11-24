import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recentNotifications = [
      {
        'title': 'Order Confirmed',
        'subtitle': 'Your order #7895 has been confirmed.',
        'icon': Icons.check_circle,
        'time': 'Just now',
        'color': Colors.green,
      },
      {
        'title': 'New Offer!',
        'subtitle': 'Flat 10% off on all Rice products this week.',
        'icon': Icons.local_offer,
        'time': '5 mins ago',
        'color': Colors.orange,
      },
    ];

    final earlierNotifications = [
      {
        'title': 'Delivery Dispatched',
        'subtitle': 'Your order #7890 is out for delivery.',
        'icon': Icons.delivery_dining,
        'time': 'Yesterday',
        'color': Colors.blue,
      },
      {
        'title': 'Profile Updated',
        'subtitle': 'You have successfully updated your profile.',
        'icon': Icons.person,
        'time': '2 days ago',
        'color': Colors.purple,
      },
      {
        'title': 'Password Changed',
        'subtitle': 'Your password was changed securely.',
        'icon': Icons.lock,
        'time': '3 days ago',
        'color': Colors.redAccent,
      },
    ];

    Widget buildNotificationCard(Map<String, dynamic> data) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: data['color'],
            child: Icon(data['icon'], color: Colors.white),
          ),
          title: Text(
            data['title'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(data['subtitle']),
          trailing: Text(
            data['time'],
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Recent",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...recentNotifications.map(buildNotificationCard).toList(),
          const SizedBox(height: 24),
          const Text(
            "Earlier",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...earlierNotifications.map(buildNotificationCard).toList(),
        ],
      ),
    );
  }
}
