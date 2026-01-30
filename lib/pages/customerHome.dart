import 'package:flutter/material.dart';
import 'package:front/pages/demo_product.dart';
import 'package:front/view_type.dart';
import '../widgets/productModel.dart';
import '../theme/app_colors.dart';

class CustomerHomePage extends StatefulWidget {
  final Function(ViewType) onSelectView;

  const CustomerHomePage({Key? key, required this.onSelectView})
    : super(key: key);

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final TextEditingController searchController = TextEditingController();

  Product? selectedProduct;
  bool isSearchFocused = false;
  String searchQuery = "";

  final List<String> categories = [
    "Cement",
    "Sand",
    "Steel",
    "Bricks",
    "Gravel",
    "Paint",
  ];

  final List<Product> products = demoProducts;

  List<Product> get filteredProducts {
    return products.where((p) {
      return p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  bool get showContent => !isSearchFocused || searchQuery.isNotEmpty;
  bool get showEmptyState => isSearchFocused && searchQuery.isEmpty;
  bool get showCategorySlider => showContent && searchQuery.isEmpty;

  // 🔹 RESET HOME STATE
  void resetHome() {
    searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      searchQuery = "";
      isSearchFocused = false;
      selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _header(),
              if (showEmptyState) _emptyState(),
              if (showCategorySlider) _categorySlider(),
              if (showContent) _productGrid(),
            ],
          ),
          if (selectedProduct != null) _productDetailModal(),
          _bottomNav(),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sand Here",
            style: TextStyle(
              fontSize: 24,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Focus(
            onFocusChange: (f) => setState(() => isSearchFocused = f),
            child: TextField(
              controller: searchController,
              onChanged: (v) {
                setState(() {
                  searchQuery = v;
                  if (v.isEmpty) {
                    isSearchFocused = false;
                  }
                });
              },
              decoration: InputDecoration(
                hintText: "Search for products...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _emptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search, size: 80, color: AppColors.bodyText),
            SizedBox(height: 12),
            Text(
              "Start typing to search",
              style: TextStyle(fontSize: 18, color: AppColors.bodyText),
            ),
            SizedBox(height: 6),
            Text(
              "Search for construction materials",
              style: TextStyle(color: AppColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CATEGORY SLIDER =================
  Widget _categorySlider() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("🏗️", style: TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(categories[i], style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= PRODUCT GRID =================
  Widget _productGrid() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          cacheExtent: 600,
          itemCount: filteredProducts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, i) {
            final p = filteredProducts[i];
            return _productCard(p);
          },
        ),
      ),
    );
  }

  Widget _productCard(Product p) {
    return GestureDetector(
      onTap: () => setState(() => selectedProduct = p),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Center(
                child: Text(p.image, style: const TextStyle(fontSize: 48)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.bodyText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${p.price}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(p.unit, style: const TextStyle(fontSize: 11)),
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
    final p = selectedProduct!;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            p.image,
                            style: const TextStyle(fontSize: 72),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Chip(label: Text(p.category)),
                      Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          title: Text(p.dealer),
                          subtitle: Text(p.dealerLocation),
                          leading: const Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Overview",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(p.description),
                      const SizedBox(height: 8),
                      const Text(
                        "Detailed Description",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(p.detailedDescription),
                      const SizedBox(height: 12),
                      Text(
                        "₹${p.price}  (${p.unit})",
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Delivery: ₹${p.deliveryPricePerKm}/km"),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {},
                          child: const Text(
                            "Add to Cart",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => selectedProduct = null),
                  ),
                ),
              ],
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
            IconButton(
              icon: const Icon(Icons.home, color: AppColors.primary),
              onPressed: () {
                resetHome();
                widget.onSelectView(ViewType.customerHome);
              },
            ),
            IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () {}),
            IconButton(icon: const Icon(Icons.person), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
