import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minimills/user/home_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final LiquidController _controller = LiquidController();
  int currentPage = 0;

  void nextPage() async {
    if (currentPage < 2) {
      _controller.animateToPage(page: currentPage + 1);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  Widget buildPage({
    required Color color,
    required String title,
    required String subtitle,
    required String body,
    required String imageUrl,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(imageUrl, height: 200),
          const SizedBox(height: 30),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 22, color: Colors.white70),
          ),
          const SizedBox(height: 15),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildPage(
        color: Colors.green,
        title: "Welcome to Mini~Mills",
        subtitle: "Fresh products from local mills",
        body: "Rice, Oils, Grains, Dals & more — direct to your home.",
        imageUrl: "https://picsum.photos/300/200",
      ),
      buildPage(
        color: Colors.orange,
        title: "Affordable & Fast",
        subtitle: "Best price. Fast delivery.",
        body: "Supporting local businesses, delivered in 48 hrs.",
        imageUrl: "https://picsum.photos/350/200",
      ),
      buildPage(
        color: Colors.indigo,
        title: "Get Started",
        subtitle: "Shop Now",
        body: "Let’s begin your journey with Mini~Mills.",
        imageUrl: "https://picsum.photos/300/180",
      ),
    ];

    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          LiquidSwipe(
            liquidController: _controller,
            pages: pages,
            enableLoop: false,
            enableSideReveal: false,
            onPageChangeCallback: (index) =>
                setState(() => currentPage = index),
            waveType: WaveType.liquidReveal,
            slideIconWidget: null,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: AnimatedSmoothIndicator(
              activeIndex: currentPage,
              count: pages.length,
              effect: const WormEffect(
                dotColor: Colors.white30,
                activeDotColor: Colors.white,
                dotHeight: 10,
                dotWidth: 10,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: ElevatedButton(
              onPressed: nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: Text(currentPage == pages.length - 1 ? "Start" : "Next"),
            ),
          ),
        ],
      ),
    );
  }
}
