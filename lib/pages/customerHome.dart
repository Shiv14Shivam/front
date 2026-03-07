import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';
import 'dart:math';

class CustomerHomePage extends StatefulWidget {
  final void Function(
    ViewType view, {
    Map<String, dynamic>? orderData,
    String? userType,
  })
  onSelectView;

  const CustomerHomePage({super.key, required this.onSelectView});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with TickerProviderStateMixin {
  final ApiService api = ApiService();

  // ═══════════════════════════════════════════════════════════════
  // HAVERSINE DISTANCE FORMULA
  // Used in the product detail modal to calculate delivery distance.
  // Same formula used in CartPage — both use customer default address
  // vs vendor warehouse address from their default address.
  // ═══════════════════════════════════════════════════════════════
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Marketplace data ─────────────────────────────────────────
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  dynamic selectedProduct;

  // ── Input controllers ────────────────────────────────────────
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // ── UI state ─────────────────────────────────────────────────
  double totalCost = 0;
  bool isLoading = true;
  bool isLoadingDetails = false;

  // ── Cart badge count ─────────────────────────────────────────
  // Loaded from GET /api/cart summary.total_items on init.
  // Updated after each successful addToCart call.
  // Displayed on the bottom nav cart icon.
  int _cartCount = 0;

  int _selectedNavIndex = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Category filter ──────────────────────────────────────────
  String selectedCategory = "All";
  List<String> categories = ["All"];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    loadMarketplace();
    _loadCartCount(); // Load real cart count from API on start
  }

  // ═══════════════════════════════════════════════════════════════
  // LOAD CART COUNT
  // Calls GET /api/cart and reads summary.total_items.
  // This keeps the bottom nav badge accurate on page load.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadCartCount() async {
    final result = await api.getCart();
    if (result["success"] == true) {
      final summary = result["summary"];
      setState(() => _cartCount = summary?["total_items"] ?? 0);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOAD MARKETPLACE
  // Fetches all active listings from GET /api/marketplace (public).
  // Extracts unique category names for the filter chips.
  // ═══════════════════════════════════════════════════════════════
  Future<void> loadMarketplace() async {
    try {
      final data = await api.getMarketplaceListings();
      final cats = <String>{"All"};
      for (final item in data) {
        final cat = item["category"]?["name"];
        if (cat != null) cats.add(cat.toString());
      }
      setState(() {
        products = data;
        filteredProducts = data;
        categories = cats.toList();
        isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOAD PRODUCT DETAILS
  // Called when user taps a product card.
  // Fetches full product info and merges with listing data.
  // ═══════════════════════════════════════════════════════════════
  Future<void> loadProductDetails(dynamic listing) async {
    setState(() => isLoadingDetails = true);
    try {
      final fullProduct = await api.getProducts(listing["product"]["id"]);
      final enhanced = {
        ...listing,
        "product": {...listing["product"], ...fullProduct},
      };
      setState(() {
        selectedProduct = enhanced;
        isLoadingDetails = false;
        totalCost = 0;
        quantityController.clear();
        distanceController.clear();
      });
    } catch (e) {
      setState(() {
        selectedProduct = listing;
        isLoadingDetails = false;
        totalCost = 0;
        quantityController.clear();
        distanceController.clear();
      });
    }
  }

  // ── Search + category filter helpers ────────────────────────
  void filterProducts(String query) =>
      _applyFilters(query: query, category: selectedCategory);

  void filterByCategory(String category) {
    setState(() => selectedCategory = category);
    _applyFilters(query: searchController.text, category: category);
  }

  void _applyFilters({required String query, required String category}) {
    setState(() {
      filteredProducts = products.where((p) {
        final name = (p["product"]["name"] ?? "").toLowerCase();
        final desc = (p["product"]["short_description"] ?? "").toLowerCase();
        final cat = (p["category"]?["name"] ?? "");
        final matchSearch =
            query.isEmpty ||
            name.contains(query.toLowerCase()) ||
            desc.contains(query.toLowerCase());
        final matchCat = category == "All" || cat == category;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  void _closeModal() {
    setState(() {
      selectedProduct = null;
      totalCost = 0;
      quantityController.clear();
      distanceController.clear();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    distanceController.dispose();
    quantityController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ─────────────────────── BUILD ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildCategoryChips(),
                      Expanded(child: _buildProductGrid()),
                    ],
                  ),
                ),
          if (isLoadingDetails) _buildLoadingOverlay(),
          if (selectedProduct != null) _productDetailModal(),
          _bottomNav(),
        ],
      ),
    );
  }

  // ─────────────────────── HEADER ──────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.primary),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Marketplace",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Find the best construction materials",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  _headerIconBtn(Icons.notifications_none_rounded, () {}),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: filterProducts,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.titleText,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search products...",
                    hintStyle: const TextStyle(
                      color: AppColors.subtleText,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.subtleText,
                      size: 20,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.subtleText,
                              size: 18,
                            ),
                            onPressed: () {
                              searchController.clear();
                              filterProducts("");
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ─────────────────────── CATEGORY CHIPS ──────────────────────
  Widget _buildCategoryChips() {
    return Container(
      height: 54,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final selected = cat == selectedCategory;
          return GestureDetector(
            onTap: () => filterByCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────── PRODUCT GRID ────────────────────────
  Widget _buildProductGrid() {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              "No products found",
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: filteredProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) => _productCard(filteredProducts[index]),
    );
  }

  Widget _productCard(dynamic p) {
    final imageUrl = p["product"]["image_url"] as String?;
    return GestureDetector(
      onTap: () => loadProductDetails(p),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              color: AppColors.shadowSoft,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(p),
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _shimmer(),
                      )
                    : _imagePlaceholder(p),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p["product"]["name"] ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.titleText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p["product"]["short_description"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.subtleText,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${p["price_per_bag"]}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              p["product"]["unit"] ?? "",
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.subtleText,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMuted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
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

  Widget _imagePlaceholder(dynamic p) {
    final name = (p["product"]["name"] ?? "").toLowerCase();
    String emoji = "🏗️";
    Color bg = AppColors.surfaceAlt;
    if (name.contains("cement")) {
      emoji = "🧱";
      bg = const Color(0xFFF0EDE8);
    } else if (name.contains("sand") || name.contains("aggregate")) {
      emoji = "⛏️";
      bg = AppColors.sandLight;
    } else if (name.contains("steel") || name.contains("iron")) {
      emoji = "🔩";
      bg = const Color(0xFFE8F0EE);
    } else if (name.contains("paint")) {
      emoji = "🎨";
      bg = const Color(0xFFF0E8F5);
    } else if (name.contains("tile") || name.contains("marble")) {
      emoji = "🔲";
    }

    return Container(
      color: bg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotPainter())),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 46)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Image coming soon",
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmer() => Container(
    color: AppColors.surfaceAlt,
    child: const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primary,
      ),
    ),
  );

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 14),
                Text(
                  "Loading details...",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.bodyText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────── PRODUCT DETAIL MODAL ────────────────
  Widget _productDetailModal() {
    final p = selectedProduct;
    final product = p["product"];
    final seller = p["seller"];
    final imageUrl = product["image_url"] as String?;

    final bool vendorHasLocation =
        seller["warehouse_lat"] != null && seller["warehouse_lng"] != null;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeModal,
        child: Container(
          color: Colors.black54,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {},
              child: Center(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 20, 14, 80),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Column(
                      children: [
                        // ── Product image ──
                        Stack(
                          children: [
                            SizedBox(
                              height: 210,
                              width: double.infinity,
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _modalPlaceholder(product),
                                    )
                                  : _modalPlaceholder(product),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.background.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _closeModal,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  p["category"]?["name"] ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Name & price ──
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product["name"] ?? "",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.titleText,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "₹${p["price_per_bag"]}",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          product["unit"] ?? "",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.subtleText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // ── Seller info card ──
                                _card(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.vendorMuted,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.store_rounded,
                                          color: AppColors.vendor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              seller["name"] ?? "",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppColors.titleText,
                                              ),
                                            ),
                                            if (seller["phone"] != null)
                                              Text(
                                                seller["phone"],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.bodyText,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.vendorMuted,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          "Verified",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.vendor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                _sectionTitle("Overview"),
                                const SizedBox(height: 6),
                                Text(
                                  product["short_description"] ?? "",
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.bodyText,
                                    height: 1.5,
                                  ),
                                ),

                                if ((product["detailed_description"] ?? "")
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  _sectionTitle("Description"),
                                  const SizedBox(height: 6),
                                  Text(
                                    product["detailed_description"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.bodyText,
                                      height: 1.5,
                                    ),
                                  ),
                                ],

                                if ((product["specifications"] ?? [])
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _sectionTitle("Specifications"),
                                  const SizedBox(height: 8),
                                  _card(
                                    child: Column(
                                      children: (product["specifications"] as List)
                                          .asMap()
                                          .entries
                                          .map((e) {
                                            final isLast =
                                                e.key ==
                                                (product["specifications"]
                                                            as List)
                                                        .length -
                                                    1;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: isLast
                                                    ? null
                                                    : Border(
                                                        bottom: BorderSide(
                                                          color:
                                                              AppColors.divider,
                                                        ),
                                                      ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 16,
                                                    color: AppColors.success,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      e.value["value"] ?? "",
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color:
                                                            AppColors.bodyText,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 18),

                                // ── Delivery charge display ──
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.borderFocus.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.local_shipping_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Delivery Charge",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppColors.titleText,
                                            ),
                                          ),
                                          Text(
                                            "₹${p["delivery_charge_per_ton"]} per km",
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                _sectionTitle("Calculate Your Cost"),
                                const SizedBox(height: 8),

                                // Location info banner
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vendorHasLocation
                                        ? AppColors.primaryMuted
                                        : AppColors.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: vendorHasLocation
                                          ? AppColors.primary.withOpacity(0.2)
                                          : AppColors.error.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        vendorHasLocation
                                            ? Icons.info_outline_rounded
                                            : Icons.warning_amber_rounded,
                                        size: 16,
                                        color: vendorHasLocation
                                            ? AppColors.primary
                                            : AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vendorHasLocation
                                              ? "Distance is auto-calculated from vendor's location to your default address."
                                              : "Vendor has not set a default address yet.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: vendorHasLocation
                                                ? AppColors.primary
                                                : AppColors.error,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── Quantity + Distance row ──
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: quantityController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.titleText,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: "Quantity",
                                          hintText: "e.g. 10",
                                          labelStyle: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.bodyText,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.inventory_2_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.surface,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: distanceController,
                                        readOnly:
                                            true, // Auto-filled by _calculateCost
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.titleText,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: "Distance (km)",
                                          hintText: "Auto",
                                          labelStyle: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.bodyText,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.route_rounded,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.surfaceAlt,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.primary,
                                              width: 1.5,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                _outlinedBtn(
                                  "Calculate",
                                  _calculateCost,
                                  icon: Icons.calculate_rounded,
                                ),
                                const SizedBox(height: 10),
                                _outlinedBtn(
                                  "Add to Cart",
                                  _addToCart,
                                  icon: Icons.shopping_cart_outlined,
                                ),
                                const SizedBox(height: 10),
                                _primaryBtn(
                                  "Request Order",
                                  _requestOrder,
                                  icon: Icons.shopping_cart_checkout_rounded,
                                ),

                                // ── Estimated cost result ──
                                if (totalCost > 0) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.vendorMuted,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.success.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Estimated Total",
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "₹${totalCost.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULATE COST
  // Fetches customer's default address coordinates.
  // Uses Haversine formula to compute distance to vendor warehouse.
  // Fills the read-only distance field and calculates total cost.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _calculateCost() async {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack("Enter a valid quantity", ok: false);
      return;
    }

    final seller = selectedProduct["seller"];
    final rawVLat = seller["warehouse_lat"];
    final rawVLng = seller["warehouse_lng"];

    if (rawVLat == null || rawVLng == null) {
      _snack("Vendor has not set a default address yet", ok: false);
      return;
    }

    final double vendorLat;
    final double vendorLng;
    try {
      vendorLat = double.parse(rawVLat.toString());
      vendorLng = double.parse(rawVLng.toString());
    } catch (_) {
      _snack("Vendor location data is invalid", ok: false);
      return;
    }

    // Fetch customer's default address with coordinates
    final addressRes = await api.getDefaultAddress();
    if (!addressRes["success"]) {
      _snack(
        addressRes["message"] ?? "Set a default address in your profile first",
        ok: false,
      );
      return;
    }

    final customer = addressRes["data"];
    final double customerLat;
    final double customerLng;
    try {
      customerLat = double.parse(customer["latitude"].toString());
      customerLng = double.parse(customer["longitude"].toString());
    } catch (_) {
      _snack("Your default address has no coordinates. Re-save it.", ok: false);
      return;
    }

    // Calculate distance using Haversine formula
    final double dist = calculateDistance(
      vendorLat,
      vendorLng,
      customerLat,
      customerLng,
    );

    final double price = double.parse(
      selectedProduct["price_per_bag"].toString(),
    );
    final double delivery = double.parse(
      selectedProduct["delivery_charge_per_ton"].toString(),
    );

    setState(() {
      distanceController.text = dist.toStringAsFixed(2);
      totalCost = (qty * price) + (dist * delivery);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ADD TO CART
  // Calls POST /api/cart with listing_id and quantity_bags.
  // The quantity entered here is stored in Cart.quantity_bags in DB.
  // CartPage reads this same quantity_bags — they are always in sync.
  //
  // Guards before calling API:
  //   1. Quantity must be > 0
  //   2. Distance must be calculated first
  //   3. Quantity must not exceed available stock
  // ═══════════════════════════════════════════════════════════════
  Future<void> _addToCart() async {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    final dist = double.tryParse(distanceController.text.trim()) ?? 0;

    // Guard 1: Quantity required
    if (qty <= 0) {
      _snack("Enter a valid quantity", ok: false);
      return;
    }

    // Guard 2: Distance must be calculated first
    // This ensures customer has a default address set
    if (dist <= 0) {
      _snack("Calculate distance first", ok: false);
      return;
    }

    final p = selectedProduct;
    final listingId = p["id"] as int?;

    if (listingId == null) {
      _snack("Invalid listing", ok: false);
      return;
    }

    // Guard 3: Check against available stock
    final stock = p["available_stock_bags"] ?? 0;
    if (qty > stock) {
      _snack("Only $stock bags available in stock", ok: false);
      return;
    }

    // Show loading overlay while API call runs
    setState(() => isLoadingDetails = true);

    // POST /api/cart — saves quantity_bags to DB
    // Backend also does stock check + active listing check + own listing check
    final result = await api.addToCart(
      listingId: listingId,
      quantityBags: qty.toInt(),
    );

    setState(() => isLoadingDetails = false);

    if (result["success"] == true) {
      // Increment cart badge count
      setState(() => _cartCount++);

      _snack(
        result["message"] ?? "${p["product"]["name"]} added to cart",
        ok: true,
        icon: Icons.shopping_cart_checkout_rounded,
      );
    } else {
      _snack(result["message"] ?? "Failed to add to cart", ok: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // REQUEST ORDER
  // Navigates to the order request page with pre-filled data.
  // Requires quantity and distance to be filled (Calculate first).
  // ═══════════════════════════════════════════════════════════════
  void _requestOrder() {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    final dist = double.tryParse(distanceController.text.trim()) ?? 0;

    if (qty <= 0 || dist <= 0) {
      _snack("Calculate cost first", ok: false);
      return;
    }

    final p = selectedProduct;
    final cost =
        (qty * double.parse(p["price_per_bag"].toString())) +
        (dist * double.parse(p["delivery_charge_per_ton"].toString()));

    widget.onSelectView(
      ViewType.requestOrder,
      orderData: {
        "listing": p,
        "quantity": qty,
        "distance": dist,
        "totalCost": cost,
      },
    );
  }

  void _snack(
    String msg, {
    required bool ok,
    IconData icon = Icons.check_circle,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? icon : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────── HELPERS ─────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadowSoft,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 15,
      color: AppColors.titleText,
    ),
  );

  Widget _primaryBtn(
    String text,
    VoidCallback onTap, {
    IconData? icon,
  }) => SizedBox(
    height: 48,
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _outlinedBtn(
    String text,
    VoidCallback onTap, {
    IconData? icon,
  }) => SizedBox(
    height: 48,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _modalPlaceholder(dynamic product) {
    final name = (product["name"] ?? "").toLowerCase();
    String emoji = "🏗️";
    if (name.contains("cement"))
      emoji = "🧱";
    else if (name.contains("sand") || name.contains("aggregate"))
      emoji = "⛏️";
    else if (name.contains("steel") || name.contains("iron"))
      emoji = "🔩";
    else if (name.contains("paint"))
      emoji = "🎨";
    else if (name.contains("tile") || name.contains("marble"))
      emoji = "🔲";

    return Container(
      color: AppColors.surfaceAlt,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotPainter())),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Photo coming soon",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── BOTTOM NAV ──────────────────────────
  Widget _bottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  Icons.home_rounded,
                  "Home",
                  0,
                  () => setState(() => _selectedNavIndex = 0),
                ),

                // Cart badge uses _cartCount from API, not local list
                _navBadge(
                  Icons.shopping_cart_rounded,
                  "Cart",
                  1,
                  _cartCount, // ← real count from GET /api/cart
                  () {
                    setState(() => _selectedNavIndex = 1);
                    widget.onSelectView(ViewType.cart);
                  },
                ),

                _navItem(Icons.person_rounded, "Profile", 2, () {
                  setState(() => _selectedNavIndex = 2);
                  widget.onSelectView(ViewType.cutomerProfile);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, VoidCallback onTap) {
    final sel = _selectedNavIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: sel ? AppColors.primary : AppColors.subtleText,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: sel ? AppColors.primary : AppColors.subtleText,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBadge(
    IconData icon,
    String label,
    int index,
    int count,
    VoidCallback onTap,
  ) {
    final sel = _selectedNavIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: sel ? AppColors.primary : AppColors.subtleText,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 9 ? "9+" : "$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: sel ? AppColors.primary : AppColors.subtleText,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 18)
      for (double y = 0; y < size.height; y += 18)
        canvas.drawCircle(Offset(x, y), 1.5, paint);
  }

  @override
  bool shouldRepaint(_DotPainter _) => false;
}
