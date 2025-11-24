import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather/weather.dart';
import '../core/product_controller.dart';
import '../core/category_controller.dart';
import '../user/user_session.dart';
import 'product_session.dart';
import 'product_service.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  static Set<int> favoriteIds = {};

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool isLoading = true;
  late Timer _timer;
  int? selectedCategoryId;
  String? temperature;
  String? weatherCondition;
  String? humidity;
  bool headerExpanded = true;
  bool gridViewProducts = false;
  bool gridViewCategories = false;

  final ProductController productController = ProductController();
  final CategoryController categoryController = CategoryController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchWeather();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await ProductService().loadProductsAndCategories();
    await productController.favoriteController.loadFavorites();
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> _fetchWeather() async {
    try {
      const apiKey = 'cdbcc184258657b19293d9cc9ac7ceff';
      final wf = WeatherFactory(apiKey);
      final lat = UserSession.latitude;
      final lon = UserSession.longitude;
      Weather w;
      if (lat != null && lon != null) {
        w = await wf.currentWeatherByLocation(lat, lon);
      } else {
        final city = UserSession.address ?? 'Kathmandu';
        w = await wf.currentWeatherByCityName(city);
      }
      if (!mounted) return;
      setState(() {
        temperature = w.temperature?.celsius?.round().toString() ?? '--';
        weatherCondition = w.weatherMain ?? 'Clear';
        humidity = w.humidity?.round().toString() ?? '--';
      });
    } catch (_) {
      setState(() {
        temperature = '--';
        weatherCondition = 'Clear';
        humidity = '--';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final formattedDate = DateFormat('MMMM d, y').format(now);
    final weekday = DateFormat('EEEE').format(now);
    final time = DateFormat('hh:mm:ss a').format(now);

    final filteredProducts = selectedCategoryId == null
        ? ProductSession.products
        : ProductSession.products
              .where((p) => p['category_id'] == selectedCategoryId)
              .toList();

    final categories = ProductSession.categories;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadInitialData();
          await _fetchWeather();
        },
        color: colors.primary,
        child: Column(
          children: [
            if (!headerExpanded)
              _buildHeader(formattedDate, weekday, time, colors),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (headerExpanded)
                      _buildHeader(formattedDate, weekday, time, colors),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Categories",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  gridViewCategories
                                      ? Icons.view_list
                                      : Icons.grid_view,
                                  color: colors.primary,
                                ),
                                onPressed: () => setState(
                                  () =>
                                      gridViewCategories = !gridViewCategories,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          gridViewCategories
                              ? categoryController.buildCategoryGrid(
                                  categories,
                                  colors,
                                  selectedCategoryId,
                                  (id) =>
                                      setState(() => selectedCategoryId = id),
                                )
                              : categoryController.buildCategoryList(
                                  selectedCategoryId: selectedCategoryId,
                                  colors: colors,
                                  onCategoryTap: (id) =>
                                      setState(() => selectedCategoryId = id),
                                ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Products",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  gridViewProducts
                                      ? Icons.view_list
                                      : Icons.grid_view,
                                  color: colors.primary,
                                ),
                                onPressed: () => setState(
                                  () => gridViewProducts = !gridViewProducts,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          gridViewProducts
                              ? productController.buildProductGrid(
                                  filteredProducts,
                                  colors,
                                  context,
                                )
                              : productController.buildProductList(
                                  filteredProducts,
                                  colors,
                                  context,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String date,
    String weekday,
    String time,
    ColorScheme colors,
  ) {
    IconData weatherIcon;
    switch (weatherCondition) {
      case 'Clouds':
        weatherIcon = Icons.cloud;
        break;
      case 'Rain':
        weatherIcon = Icons.grain;
        break;
      case 'Snow':
        weatherIcon = Icons.ac_unit;
        break;
      default:
        weatherIcon = Icons.wb_sunny_outlined;
    }

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$date ~ $weekday',
                style: TextStyle(color: colors.onSurface),
              ),
              Text(time, style: TextStyle(color: colors.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${UserSession.firstName ?? 'Dear'} ${UserSession.lastName ?? 'User'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      UserSession.address ?? 'Kathmandu, Nepal',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(weatherIcon, size: 28, color: Colors.amber),
                  Text(
                    '${temperature ?? "--"}°C | ${humidity ?? "--"}%',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Center(
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                headerExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: colors.primary,
                size: 28,
              ),
              onPressed: () => setState(() => headerExpanded = !headerExpanded),
            ),
          ),
        ],
      ),
    );
  }
}
