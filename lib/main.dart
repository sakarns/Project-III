import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:minimills/settings/forgot_password.dart';
import 'package:minimills/core/theme_controller.dart';
import 'package:minimills/user/notifications_page.dart';
import 'package:minimills/user/splash_screen.dart';
import 'package:minimills/onboarding/onboarding_screen.dart';
import 'package:minimills/user/home_page.dart';
import 'package:minimills/user/profile_page.dart';
import 'package:minimills/user/about_page.dart';
import 'package:minimills/user/messages_page.dart';
import 'package:minimills/user/settings_page.dart';
import 'package:minimills/user/register_page.dart';
import 'package:minimills/user/login_page.dart';
import 'package:minimills/user/logout_page.dart';
import 'package:minimills/shop/shop_page.dart';
import 'package:minimills/admin/admin_main.dart';
import 'package:minimills/shop/my_favorite_page.dart';
import 'package:minimills/shop/add_to_cart_page.dart';
import 'package:minimills/shop/order_page.dart';
import 'package:minimills/shop/checkout_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://plmmfgkhsgyecifytgmy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsbW1mZ2toc2d5ZWNpZnl0Z215Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NTM4MTUsImV4cCI6MjA3OTEyOTgxNX0.YOsYFdjrviaiRcXZdxiX2cCBitItgmEe1mOrReRvKkM',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();

  ThemeData get lightTheme => ThemeData.light(useMaterial3: true);

  ThemeData get darkTheme => ThemeData.dark(useMaterial3: true);

  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
  }

  void _handleDeepLinks() {
    // Listen for deep links when app is running
    _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && uri.host == 'reset-callback') {
          final token = uri.queryParameters['access_token'];
          if (token != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ForgotPassword(accessToken: token),
              ),
            );
          }
        }
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );

    _appLinks
        .getInitialLink()
        .then((Uri? uri) {
          if (uri != null && uri.host == 'reset-callback') {
            final token = uri.queryParameters['access_token'];
            if (token != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ForgotPassword(accessToken: token),
                  ),
                );
              });
            }
          }
        })
        .catchError((err) {
          debugPrint('Initial link error: $err');
        });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Mini~Mills',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const SplashScreen(),
          routes: {
            '/forgot-password': (context) => const ForgotPassword(),
            '/notifications': (context) => const NotificationsPage(),
            '/checkout': (context) => const CheckoutPage(),
            '/order': (context) => const OrderPage(),
            '/favorite': (context) => MyFavoritePage(),
            '/cart': (context) => const AddToCartPage(),
            '/shop': (context) => const ShopPage(),
            '/home': (context) => const HomePage(),
            '/profile': (context) => const ProfilePage(),
            '/about': (context) => const AboutPage(),
            '/messages': (context) => const MessagesPage(),
            '/settings': (context) => const SettingsPage(),
            '/register': (context) => const RegisterPage(),
            '/login': (context) => const LoginPage(),
            '/logout': (context) => const LogoutPage(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/admin': (context) => const AdminHomePage(),
          },
        );
      },
    );
  }
}
