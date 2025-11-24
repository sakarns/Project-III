import 'package:flutter/material.dart';
import 'package:minimills/shop/order_page.dart';
import 'cart_service.dart';
import 'dart:async';
import 'order_service.dart';
import '../core/product_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddToCartPage extends StatefulWidget {
  const AddToCartPage({super.key});

  @override
  State<AddToCartPage> createState() => _AddToCartPageState();
}

class _AddToCartPageState extends State<AddToCartPage> {
  final cartService = CartService();
  final orderService = OrderService();
  final _supabase = Supabase.instance.client;
  final ProductController productController = ProductController();
  bool isPlacingOrder = false;
  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final items = await cartService.getCartItems();
    await productController.favoriteController.loadFavorites();
    if (!mounted) return;
    setState(() => cartItems = items);
  }

  Future<void> _removeItem(int index) async {
    await cartService.removeFromCart(cartItems[index]['id']);
    if (!mounted) return;
    await _loadCart();
  }

  String formatPrice(num price) =>
      price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);

  void _openEditSheet(Map<String, dynamic> item) {
    final product = item['products'] ?? {};
    double quantity = (item['quantity'] ?? 1).toDouble();
    String requirements = item['describe_requirements'] ?? '';
    bool isPacked = true;
    double productQuantity = (product['quantity'] ?? 1).toDouble();
    num pricePerUnit = product['price_per_unit'] ?? 0;
    num sellingPrice = product['selling_price'] ?? 0;
    Timer? incTimer;
    Timer? decTimer;
    final TextEditingController quantityController = TextEditingController(
      text: quantity.toStringAsFixed(0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            num getTotalPrice() {
              num perUnitRate = quantity >= productQuantity
                  ? sellingPrice / productQuantity
                  : pricePerUnit;
              return perUnitRate * quantity;
            }

            void updateQuantityForToggle(bool packed) {
              if (packed) {
                quantity = ((quantity ~/ productQuantity) * productQuantity)
                    .clamp(productQuantity, 9999);
              } else {
                quantity = quantity.clamp(0.2, 9999);
              }
              quantityController.text = quantity.toStringAsFixed(
                packed ? 0 : 2,
              );
            }

            void increment() {
              setModalState(() {
                if (!isPacked) {
                  quantity = (quantity + 0.05).clamp(0.2, 9999);
                  quantity = double.parse(quantity.toStringAsFixed(2));
                } else {
                  quantity = (quantity + productQuantity).clamp(
                    productQuantity,
                    9999,
                  );
                }
                quantityController.text = quantity.toStringAsFixed(
                  isPacked ? 0 : 2,
                );
              });
            }

            void decrement() {
              setModalState(() {
                if (!isPacked) {
                  quantity = (quantity - 0.05).clamp(0.2, 9999);
                  quantity = double.parse(quantity.toStringAsFixed(2));
                } else {
                  quantity = (quantity - productQuantity).clamp(
                    productQuantity,
                    9999,
                  );
                }
                quantityController.text = quantity.toStringAsFixed(
                  isPacked ? 0 : 2,
                );
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child:
                            product['signed_image_url'] != null &&
                                product['signed_image_url'].isNotEmpty
                            ? Image.network(
                                product['signed_image_url'],
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: colors.surface,
                                child: const Icon(Icons.shopping_bag),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Product',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Price/${product['unit'] ?? ''}: Rs.${formatPrice(pricePerUnit)}',
                            ),
                            Text(
                              'Quantity: ${formatPrice(productQuantity)} ${product['unit'] ?? ''}',
                            ),
                            Text(
                              'Selling Price: Rs.${formatPrice(sellingPrice)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() {
                          isPacked = false;
                          updateQuantityForToggle(isPacked);
                        }),
                        child: Text(
                          'Open',
                          style: TextStyle(
                            color: !isPacked
                                ? colors.primary
                                : colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setModalState(() {
                          isPacked = true;
                          updateQuantityForToggle(isPacked);
                        }),
                        child: Text(
                          'Packed',
                          style: TextStyle(
                            color: isPacked ? colors.primary : colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTapDown: (_) {
                          decrement();
                          decTimer = Timer.periodic(
                            const Duration(milliseconds: 150),
                            (_) => decrement(),
                          );
                        },
                        onTapUp: (_) => decTimer?.cancel(),
                        onTapCancel: () => decTimer?.cancel(),
                        child: const Icon(
                          Icons.remove_circle_outline,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (val) {
                            double? v = double.tryParse(val);
                            if (v != null) {
                              setModalState(() {
                                if (!isPacked) {
                                  quantity = double.parse(
                                    v.toStringAsFixed(2),
                                  ).clamp(0.2, 9999);
                                } else {
                                  quantity = v.clamp(productQuantity, 9999);
                                }
                              });
                            }
                          },
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTapDown: (_) {
                          increment();
                          incTimer = Timer.periodic(
                            const Duration(milliseconds: 150),
                            (_) => increment(),
                          );
                        },
                        onTapUp: (_) => incTimer?.cancel(),
                        onTapCancel: () => incTimer?.cancel(),
                        child: const Icon(Icons.add_circle_outline, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Order:\n${quantity.toStringAsFixed(isPacked ? 0 : 2)} ${product['unit'] ?? ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        'Total:\n Rs.${formatPrice(getTotalPrice())}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: requirements),
                    onChanged: (val) => requirements = val,
                    decoration: const InputDecoration(
                      labelText: 'Describe Requirements',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await cartService.updateCartItem(
                        item['id'],
                        quantity.toInt(),
                        requirements: requirements.isNotEmpty
                            ? requirements
                            : null,
                      );
                      navigator.pop();
                      await _loadCart();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Edit'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    setState(() => isPlacingOrder = true);
    final List<Map<String, dynamic>> orderItems = cartItems.map((item) {
      final product = item['products'] ?? {};
      final orderQuantity = (item['quantity'] ?? 1).toDouble();
      final productQuantity = (product['quantity'] ?? 1).toDouble();
      final pricePerUnit = (product['price_per_unit'] ?? 0).toDouble();
      final sellingPrice = (product['selling_price'] ?? 0).toDouble();
      final perUnitRate = orderQuantity >= productQuantity
          ? sellingPrice / productQuantity
          : pricePerUnit;
      final totalPrice = perUnitRate * orderQuantity;
      final discount = ((pricePerUnit * orderQuantity) - totalPrice).clamp(
        0,
        double.infinity,
      );
      return {
        'product_id': product['id'],
        'order_quantity': orderQuantity,
        'total_price': totalPrice,
        'discount': discount,
        'describe_requirements': item['describe_requirements'] ?? '',
        'cart_id': item['id'],
      };
    }).toList();

    await orderService.placeOrders(orderItems);

    for (var item in cartItems) {
      await _supabase
          .from('cart')
          .update({'is_ordered': true})
          .eq('id', item['id']);
    }

    await _loadCart();
    if (mounted) {
      setState(() => isPlacingOrder = false);
      Navigator.of(context).pushNamed('/order');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pending_actions),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCart,
        color: colors.primary,
        child: cartItems.isEmpty
            ? ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Your cart is empty',
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final product = item['products'] ?? {};
                  final pricePerUnit = (product['price_per_unit'] ?? 0)
                      .toDouble();
                  final productQuantity = (product['quantity'] ?? 1).toDouble();
                  final sellingPrice = (product['selling_price'] ?? 0)
                      .toDouble();
                  final orderQuantity = (item['quantity'] ?? 1).toDouble();
                  num perUnitRate = orderQuantity >= productQuantity
                      ? sellingPrice / productQuantity
                      : pricePerUnit;
                  num totalPrice = perUnitRate * orderQuantity;
                  num discount = (pricePerUnit * orderQuantity) - totalPrice;
                  if (discount < 0) discount = 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 160,
                                child:
                                    product['signed_image_url'] != null &&
                                        product['signed_image_url'].isNotEmpty
                                    ? Image.network(
                                        product['signed_image_url'],
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: colors.surface,
                                        child: const Icon(Icons.shopping_bag),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'] ?? 'Product',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Price/${product['unit'] ?? ''}: Rs.${formatPrice(pricePerUnit)}',
                                    ),
                                    Text(
                                      'Quantity: ${formatPrice(productQuantity)} ${product['unit'] ?? ''}',
                                    ),
                                    Text(
                                      'Selling Price: Rs.${formatPrice(sellingPrice)}',
                                    ),
                                    Text(
                                      'Order: ${formatPrice(orderQuantity)} ${product['unit'] ?? ''}',
                                    ),
                                    Text(
                                      'Discount: Rs.${formatPrice(discount)}',
                                    ),
                                    Text(
                                      'Total Price: Rs.${formatPrice(totalPrice)}',
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () => _openEditSheet(item),
                                    icon: Icon(
                                      Icons.edit,
                                      color: colors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeItem(index),
                                    icon: Icon(
                                      Icons.delete,
                                      color: colors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if ((item['describe_requirements'] ?? '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Requirements: ${item['describe_requirements']}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: cartItems.isNotEmpty
          ? Builder(
              builder: (context) => Container(
                padding: const EdgeInsets.all(16),
                color: colors.surface,
                child: ElevatedButton(
                  onPressed: isPlacingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: isPlacingOrder
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Ready to Order',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
