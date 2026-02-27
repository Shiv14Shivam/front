import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';

class CustomerHomePage extends StatefulWidget {
  final Function(ViewType) onSelectView;

  const CustomerHomePage({super.key, required this.onSelectView});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final ApiService api = ApiService();

  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  dynamic selectedProduct;

  final TextEditingController distanceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  double totalCost = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMarketplace();
  }

  Future<void> loadMarketplace() async {
    try {
      final data = await api.getMarketplaceListings();
      setState(() {
        products = data;
        filteredProducts = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🔥 NEW: Fetch full product details while keeping listing prices
  Future<void> loadProductDetails(dynamic listing) async {
    try {
      final fullProduct = await api.getProducts(listing["product"]["id"]);
      final enhancedListing = {
        ...listing, // Keep ALL marketplace pricing data
        "product": {
          ...listing["product"], // Keep basic info
          ...fullProduct, // Add specifications
        },
      };
      setState(() => selectedProduct = enhancedListing);
    } catch (e) {
      // Fallback to original listing if API fails
      setState(() => selectedProduct = listing);
    }
  }

  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((p) {
          final name = (p["product"]["name"] ?? "").toLowerCase();
          final desc = (p["product"]["short_description"] ?? "").toLowerCase();
          return name.contains(query.toLowerCase()) ||
              desc.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    distanceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Search Bar - Amazon style
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterProducts,
                        decoration: InputDecoration(
                          hintText: "Search products...",
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    filterProducts("");
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount: filteredProducts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          return _productCard(p);
                        },
                      ),
                    ),
                  ],
                ),

          if (selectedProduct != null) _productDetailModal(),

          _bottomNav(),
        ],
      ),
    );
  }

  // ================= PRODUCT CARD =================
  Widget _productCard(dynamic p) {
    return GestureDetector(
      onTap: () => loadProductDetails(p), // 🔥 Now fetches specs + keeps prices
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EEF7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: const Text("🏗️", style: TextStyle(fontSize: 48)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p["product"]["name"],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p["product"]["short_description"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${p["price_per_bag"]}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    p["product"]["unit"] ?? "",
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= PRODUCT DETAIL MODAL =================
  Widget _productDetailModal() {
    final p = selectedProduct;
    final product = p["product"];
    final seller = p["seller"];

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => selectedProduct = null),
                        ),
                      ),

                      // IMAGE
                      Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Text(
                          "🏗️",
                          style: TextStyle(fontSize: 80),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Chip(label: Text(p["category"]["name"])),

                      const SizedBox(height: 12),

                      // SELLER CARD
                      Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(seller["name"]),
                          subtitle: Text(seller["phone"] ?? ""),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        "Overview",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(product["short_description"] ?? ""),

                      const SizedBox(height: 12),

                      const Text(
                        "Detailed Description",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(product["detailed_description"] ?? ""),

                      const SizedBox(height: 12),

                      // 🔥 FIXED SPECIFICATIONS - Same as AddProductPage
                      const Text(
                        "Specifications",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...(product["specifications"] ?? [])
                          .map<Widget>(
                            (spec) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      spec["value"] ?? "",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Color(0xFF444444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${p["price_per_bag"]} (${product["unit"]})",
                              style: const TextStyle(
                                fontSize: 20,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Delivery: ₹${p["delivery_charge_per_ton"]} per km",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Enter Quantity",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: distanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Enter distance in km",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (totalCost > 0)
                        Text(
                          "Total Cost: ₹${totalCost.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: () {
                          final qty =
                              double.tryParse(quantityController.text) ?? 0;
                          final dist =
                              double.tryParse(distanceController.text) ?? 0;

                          setState(() {
                            totalCost =
                                (qty * double.parse(p["price_per_bag"])) +
                                (dist *
                                    double.parse(p["delivery_charge_per_ton"]));
                          });
                        },
                        child: const Text("View Total Cost"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {},
                        child: const Text("Request Order"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= BOTTOM NAV =================
  Widget _bottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Icon(Icons.home, color: AppColors.primary),
            const Icon(Icons.shopping_cart),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => widget.onSelectView(ViewType.cutomerProfile),
            ),
          ],
        ),
      ),
    );
  }
}
