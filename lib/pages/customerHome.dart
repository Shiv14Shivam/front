import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';
import '../utils/responsive.dart';
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

  // ── State ──────────────────────────────────────────────────────────────────
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  dynamic selectedProduct;

  final searchController = TextEditingController();
  final distanceController = TextEditingController();
  final quantityController = TextEditingController();

  double totalCost = 0;
  bool isLoading = true;
  bool isLoadingDetails = false;
  int _cartCount = 0;
  int _selectedNavIndex = 0;

  String selectedCategory = "All";
  List<String> categories = ["All"];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Init ───────────────────────────────────────────────────────────────────
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
    _loadMarketplace();
    _loadCartCount();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    searchController.dispose();
    distanceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  // ── Data loaders ───────────────────────────────────────────────────────────
  Future<void> _loadMarketplace() async {
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
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCartCount() async {
    final result = await api.getCart();
    if (result["success"] == true) {
      final summary = result["summary"];
      setState(() => _cartCount = summary?["total_items"] ?? 0);
    }
  }

  Future<void> _loadProductDetails(dynamic listing) async {
    setState(() => isLoadingDetails = true);
    try {
      final full = await api.getProducts(listing["product"]["id"]);
      setState(() {
        selectedProduct = {
          ...listing,
          "product": {...listing["product"], ...full},
        };
        isLoadingDetails = false;
        totalCost = 0;
        quantityController.clear();
        distanceController.clear();
      });
    } catch (_) {
      setState(() {
        selectedProduct = listing;
        isLoadingDetails = false;
        totalCost = 0;
        quantityController.clear();
        distanceController.clear();
      });
    }
  }

  // ── Filters ────────────────────────────────────────────────────────────────
  void _filterProducts(String query) =>
      _applyFilters(query: query, category: selectedCategory);

  void _filterByCategory(String cat) {
    setState(() => selectedCategory = cat);
    _applyFilters(query: searchController.text, category: cat);
  }

  void _applyFilters({required String query, required String category}) {
    setState(() {
      filteredProducts = products.where((p) {
        final name = (p["product"]["name"] ?? "").toLowerCase();
        final desc = (p["product"]["short_description"] ?? "").toLowerCase();
        final cat = (p["category"]?["name"] ?? "");
        final matchQ =
            query.isEmpty ||
            name.contains(query.toLowerCase()) ||
            desc.contains(query.toLowerCase());
        final matchC = category == "All" || cat == category;
        return matchQ && matchC;
      }).toList();
    });
  }

  void _closeModal() => setState(() {
    selectedProduct = null;
    totalCost = 0;
    quantityController.clear();
    distanceController.clear();
  });

  // ── Firm name helper ───────────────────────────────────────────────────────
  String _firmName(Map<String, dynamic> seller) {
    final direct = seller["firm_name"];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    final vendor = seller["vendor"];
    if (vendor is Map) {
      final n = vendor["firm_name"];
      if (n is String && n.trim().isNotEmpty) return n.trim();
    }
    return (seller["name"] as String? ?? "").trim();
  }

  // ── Distance calc ──────────────────────────────────────────────────────────
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
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

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb && !Responsive.isMobile(context);

    return WebScaffold(
      isVendor: false,
      onSelectView: widget.onSelectView,
      selectedIndex: 0,
      body: Scaffold(
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
                        if (!isDesktop) _buildMobileHeader(),
                        _buildSearchAndChips(isDesktop: isDesktop),
                        Expanded(child: _buildGrid(isDesktop: isDesktop)),
                      ],
                    ),
                  ),

            if (isLoadingDetails) _loadingOverlay(),
            if (selectedProduct != null) _detailModal(isDesktop: isDesktop),
            if (!isDesktop) _bottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── Mobile header ─────────────────────────────────────────────────────────
  Widget _buildMobileHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Marketplace",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Browse construction materials",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                _iconBtn(
                  Icons.notifications_none_rounded,
                  () => widget.onSelectView(ViewType.notifications),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _searchBar(onDark: true),
          ],
        ),
      ),
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );

  // ─── Search + chips ────────────────────────────────────────────────────────
  Widget _buildSearchAndChips({required bool isDesktop}) => Container(
    color: Colors.white,
    child: Column(
      children: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _searchBar(onDark: false),
          ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final selected = cat == selectedCategory;
              return GestureDetector(
                onTap: () => _filterByCategory(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.bodyText,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    ),
  );

  Widget _searchBar({required bool onDark}) => Container(
    decoration: BoxDecoration(
      color: onDark ? Colors.white : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      border: onDark ? null : Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: searchController,
      onChanged: _filterProducts,
      style: const TextStyle(fontSize: 14, color: AppColors.titleText),
      decoration: InputDecoration(
        hintText: "Search cement, sand, steel...",
        hintStyle: const TextStyle(color: AppColors.subtleText, fontSize: 13),
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
                  _filterProducts("");
                },
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    ),
  );

  // ─── Product grid ──────────────────────────────────────────────────────────
  Widget _buildGrid({required bool isDesktop}) {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              "No products found",
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Try a different search or category",
              style: TextStyle(color: AppColors.subtleText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final columns = Responsive.value<int>(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 16,
        isDesktop ? 24 : 16,
        isDesktop ? 24 : 16,
        isDesktop ? 40 : 100,
      ),
      itemCount: filteredProducts.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: isDesktop ? 0.78 : 0.68,
        crossAxisSpacing: isDesktop ? 20 : 14,
        mainAxisSpacing: isDesktop ? 20 : 14,
      ),
      itemBuilder: (_, i) =>
          _productCard(filteredProducts[i], isDesktop: isDesktop),
    );
  }

  // ─── Product card ──────────────────────────────────────────────────────────
  Widget _productCard(dynamic p, {required bool isDesktop}) {
    final imageUrl = p["product"]["image_url"] as String?;
    final name = p["product"]["name"] ?? "";
    final desc = p["product"]["short_description"] ?? "";
    final price = p["price_per_unit"];
    final unit = p["product"]["unit"] ?? "";
    final category = p["category"]?["name"] ?? "";

    return GestureDetector(
      onTap: () => _loadProductDetails(p),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image area ──────────────────────────────────────────────
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder(name, category),
                          loadingBuilder: (_, child, prog) =>
                              prog == null ? child : _shimmer(),
                        )
                      : _placeholder(name, category),
                ),
              ),

              // ── Info area ───────────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 14 : 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name + desc
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isDesktop ? 14 : 13,
                              color: AppColors.titleText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),

                      // Price + arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "₹$price",
                                style: TextStyle(
                                  fontSize: isDesktop ? 17 : 16,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.subtleText,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.primaryMuted,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
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
      ),
    );
  }

  // ─── Image placeholder ─────────────────────────────────────────────────────
  Widget _placeholder(String name, String category) {
    final n = name.toLowerCase();
    late IconData icon;
    late Color bgColor;
    late Color iconColor;

    if (n.contains("cement") || category.toLowerCase().contains("cement")) {
      icon = Icons.layers_rounded;
      bgColor = const Color(0xFFF5F0EA);
      iconColor = const Color(0xFFB5895A);
    } else if (n.contains("sand") ||
        n.contains("aggregate") ||
        category.toLowerCase().contains("sand")) {
      icon = Icons.grain_rounded;
      bgColor = const Color(0xFFFDF5E6);
      iconColor = const Color(0xFFD4973A);
    } else if (n.contains("steel") ||
        n.contains("iron") ||
        category.toLowerCase().contains("steel")) {
      icon = Icons.view_module_rounded;
      bgColor = const Color(0xFFEEF2F5);
      iconColor = const Color(0xFF5B7A8C);
    } else if (n.contains("paint")) {
      icon = Icons.format_paint_rounded;
      bgColor = const Color(0xFFF3EEF9);
      iconColor = const Color(0xFF8B5CF6);
    } else {
      icon = Icons.construction_rounded;
      bgColor = AppColors.surfaceAlt;
      iconColor = AppColors.bodyText;
    }

    return Container(
      color: bgColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle dot texture
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPainter(iconColor.withOpacity(0.12)),
            ),
          ),
          Icon(icon, size: 42, color: iconColor.withOpacity(0.6)),
        ],
      ),
    );
  }

  Widget _shimmer() => Container(
    color: AppColors.surfaceAlt,
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );

  // ─── Loading overlay ───────────────────────────────────────────────────────
  Widget _loadingOverlay() => Positioned.fill(
    child: Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14),
              Text(
                "Loading...",
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

  // ══════════════════════════════════════════════════════════════════════════
  //  PRODUCT DETAIL MODAL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _detailModal({required bool isDesktop}) {
    final p = selectedProduct;
    final product = p["product"] as Map<String, dynamic>;
    final seller = p["seller"] as Map<String, dynamic>;
    final imageUrl = product["image_url"] as String?;
    final vendorHasLoc =
        seller["warehouse_lat"] != null && seller["warehouse_lng"] != null;
    final firmName = _firmName(seller);
    final category = p["category"]?["name"] ?? "";

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
                  margin: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 80 : 16,
                    vertical: isDesktop ? 32 : 20,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 680 : double.infinity,
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        // ── Image header ──────────────────────────────────
                        Stack(
                          children: [
                            SizedBox(
                              height: isDesktop ? 240 : 200,
                              width: double.infinity,
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(
                                            product["name"] ?? "",
                                            category,
                                          ),
                                    )
                                  : _placeholder(
                                      product["name"] ?? "",
                                      category,
                                    ),
                            ),
                            // Gradient fade at bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.95),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Category chip
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            // Close btn
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _closeModal,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── Scrollable body ───────────────────────────────
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name + price row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product["name"] ?? "",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.titleText,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "₹${p["price_per_unit"]}",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
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
                                const SizedBox(height: 16),

                                // Vendor card
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.vendorMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.vendor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.vendor.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.store_rounded,
                                          color: AppColors.vendor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              firmName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppColors.titleText,
                                              ),
                                            ),
                                            if (seller["phone"] != null)
                                              Text(
                                                seller["phone"].toString(),
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
                                          color: AppColors.vendor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          "Verified",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // Description
                                _sectionTitle("Overview"),
                                const SizedBox(height: 6),
                                Text(
                                  product["short_description"] ?? "",
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.bodyText,
                                    height: 1.55,
                                  ),
                                ),

                                if ((product["detailed_description"] ?? "")
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  _sectionTitle("Details"),
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

                                // Specifications
                                if ((product["specifications"] ?? [])
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _sectionTitle("Specifications"),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
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
                                                              AppColors.border,
                                                        ),
                                                      ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 15,
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

                                // Delivery charge
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMuted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(
                                        0.15,
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
                                            "₹${p["delivery_charge_per_km"]} per km",
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

                                // Calculate section
                                _sectionTitle("Calculate Your Cost"),
                                const SizedBox(height: 10),

                                // Location notice
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vendorHasLoc
                                        ? AppColors.primaryMuted
                                        : AppColors.error.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: vendorHasLoc
                                          ? AppColors.primary.withOpacity(0.2)
                                          : AppColors.error.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        vendorHasLoc
                                            ? Icons.info_outline_rounded
                                            : Icons.warning_amber_rounded,
                                        size: 15,
                                        color: vendorHasLoc
                                            ? AppColors.primary
                                            : AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          vendorHasLoc
                                              ? "Distance auto-calculated from vendor's location to your default address."
                                              : "Vendor has not set a default address yet.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: vendorHasLoc
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

                                // Qty + Distance inputs
                                Row(
                                  children: [
                                    Expanded(
                                      child: _calcField(
                                        controller: quantityController,
                                        label: "Quantity",
                                        hint: "e.g. 10",
                                        icon: Icons.inventory_2_outlined,
                                        readOnly: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _calcField(
                                        controller: distanceController,
                                        label: "Distance (km)",
                                        hint: "Auto",
                                        icon: Icons.route_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Action buttons
                                _outlineBtn(
                                  "Calculate",
                                  _calculateCost,
                                  icon: Icons.calculate_rounded,
                                ),
                                const SizedBox(height: 8),
                                _outlineBtn(
                                  "Add to Cart",
                                  _addToCart,
                                  icon: Icons.shopping_cart_outlined,
                                ),
                                const SizedBox(height: 8),
                                _primaryBtn(
                                  "Request Order",
                                  _requestOrder,
                                  icon: Icons.shopping_cart_checkout_rounded,
                                ),

                                // Total cost
                                if (totalCost > 0) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
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
                                            fontWeight: FontWeight.w900,
                                            fontSize: 22,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
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

  // ─── Calc field ────────────────────────────────────────────────────────────
  Widget _calcField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool readOnly,
  }) => TextField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: readOnly ? null : TextInputType.number,
    style: const TextStyle(fontSize: 14, color: AppColors.titleText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.bodyText),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 17),
      filled: true,
      fillColor: readOnly ? AppColors.surfaceAlt : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );

  // ─── Order actions ─────────────────────────────────────────────────────────
  Future<void> _calculateCost() async {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack("Enter a valid quantity", ok: false);
      return;
    }

    final seller = selectedProduct["seller"] as Map<String, dynamic>;
    final rawLat = seller["warehouse_lat"];
    final rawLng = seller["warehouse_lng"];
    if (rawLat == null || rawLng == null) {
      _snack("Vendor has not set a location yet", ok: false);
      return;
    }

    double vendorLat, vendorLng;
    try {
      vendorLat = double.parse(rawLat.toString());
      vendorLng = double.parse(rawLng.toString());
    } catch (_) {
      _snack("Vendor location data is invalid", ok: false);
      return;
    }

    final addrRes = await api.getDefaultAddress();
    if (!addrRes["success"]) {
      _snack(addrRes["message"] ?? "Set a default address first", ok: false);
      return;
    }

    final customer = addrRes["data"];
    double customerLat, customerLng;
    try {
      customerLat = double.parse(customer["latitude"].toString());
      customerLng = double.parse(customer["longitude"].toString());
    } catch (_) {
      _snack("Your default address has no coordinates. Re-save it.", ok: false);
      return;
    }

    final dist = _haversine(vendorLat, vendorLng, customerLat, customerLng);
    final price = double.parse(selectedProduct["price_per_unit"].toString());
    final delivery = double.parse(
      selectedProduct["delivery_charge_per_km"].toString(),
    );

    setState(() {
      distanceController.text = dist.toStringAsFixed(2);
      totalCost = (qty * price) + (dist * delivery);
    });
  }

  Future<void> _addToCart() async {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    final dist = double.tryParse(distanceController.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack("Enter a valid quantity", ok: false);
      return;
    }
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

    final stock = p["available_stock_unit"] ?? 0;
    if (qty > stock) {
      _snack("Only $stock unit available", ok: false);
      return;
    }

    setState(() => isLoadingDetails = true);
    final result = await api.addToCart(
      listingId: listingId,
      quantityunit: qty.toInt(),
    );
    setState(() => isLoadingDetails = false);

    if (result["success"] == true) {
      setState(() => _cartCount++);
      _snack(
        result["message"] ?? "${p["product"]["name"]} added to cart",
        ok: true,
        icon: Icons.shopping_cart_outlined,
      );
    } else {
      _snack(result["message"] ?? "Failed to add to cart", ok: false);
    }
  }

  void _requestOrder() {
    final qty = double.tryParse(quantityController.text.trim()) ?? 0;
    final dist = double.tryParse(distanceController.text.trim()) ?? 0;
    if (qty <= 0 || dist <= 0) {
      _snack("Calculate cost first", ok: false);
      return;
    }
    final p = selectedProduct;
    final cost =
        (qty * double.parse(p["price_per_unit"].toString())) +
        (dist * double.parse(p["delivery_charge_per_km"].toString()));
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

  // ─── Snack helper ──────────────────────────────────────────────────────────
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
              size: 17,
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

  // ─── Shared widget helpers ─────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );

  Widget _outlineBtn(
    String text,
    VoidCallback onTap, {
    IconData? icon,
  }) => SizedBox(
    height: 46,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 6)],
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  // ─── Bottom nav (mobile only) ──────────────────────────────────────────────
  Widget _bottomNav() => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
                Icons.store_rounded,
                "Home",
                0,
                () => setState(() => _selectedNavIndex = 0),
              ),
              _navBadgeItem(
                Icons.shopping_cart_rounded,
                "Cart",
                1,
                _cartCount,
                () {
                  setState(() => _selectedNavIndex = 1);
                  widget.onSelectView(ViewType.cart);
                },
              ),
              _navItem(Icons.person_rounded, "Profile", 2, () {
                setState(() => _selectedNavIndex = 2);
                widget.onSelectView(ViewType.customerProfile);
              }),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _navItem(IconData icon, String label, int idx, VoidCallback onTap) {
    final sel = _selectedNavIndex == idx;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: sel ? AppColors.primary : AppColors.subtleText,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: sel ? AppColors.primary : AppColors.subtleText,
              fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBadgeItem(
    IconData icon,
    String label,
    int idx,
    int count,
    VoidCallback onTap,
  ) {
    final sel = _selectedNavIndex == idx;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
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
                  size: 22,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 9 ? "9+" : "$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
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
              fontSize: 10,
              color: sel ? AppColors.primary : AppColors.subtleText,
              fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot texture painter ────────────────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  final Color color;
  const _DotPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 0; x < size.width; x += 20)
      for (double y = 0; y < size.height; y += 20)
        canvas.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
