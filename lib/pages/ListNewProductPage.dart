import 'package:flutter/material.dart';
import '../view_type.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/web_scaffold.dart';

class AddProductPage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  const AddProductPage({super.key, required this.onSelectView});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();

  String selectedCategory = '';
  String selectedBrand = '';
  String selectedProduct = '';

  List<dynamic> categories = [];
  List<dynamic> brands = [];
  List<dynamic> products = [];

  dynamic selectedCategoryObj;
  dynamic selectedBrandObj;
  dynamic selectedProductObj;

  final priceController = TextEditingController();
  final deliveryController = TextEditingController();
  final stockController = TextEditingController();
  final riverSourceController = TextEditingController();

  bool showSuccess = false;
  bool isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  bool isSandCategory() => selectedCategory.toLowerCase() == 'sand';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    fetchCategories();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    priceController.dispose();
    deliveryController.dispose();
    stockController.dispose();
    riverSourceController.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    try {
      categories = await api.getCategories();
      setState(() {});
    } catch (_) {
      if (mounted) _showSnack('Failed to load categories', isSuccess: false);
    }
  }

  Future<void> fetchProductsByCategory(int categoryId) async {
    try {
      products = await api.getProductsByCategory(categoryId);
      setState(() {});
    } catch (_) {
      if (mounted) _showSnack('Failed to load products', isSuccess: false);
    }
  }

  Future<void> fetchBrands(int categoryId) async {
    try {
      brands = await api.getBrands(categoryId);
      setState(() {});
    } catch (_) {
      if (mounted) _showSnack('Failed to load brands', isSuccess: false);
    }
  }

  Future<void> fetchProducts(int brandId) async {
    try {
      products = await api.getProducts(brandId);
      setState(() {});
    } catch (_) {
      if (mounted) _showSnack('Failed to load products', isSuccess: false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> getCategories() =>
      categories.map((c) => c['name'].toString()).toList();

  List<String> getBrands() {
    if (selectedCategoryObj == null) return [];
    return brands.map((b) => b['name'].toString()).toList();
  }

  List<dynamic> getProducts() {
    if (isSandCategory()) return products;
    if (selectedBrandObj == null) return [];
    return products;
  }

  IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cement':
        return Icons.domain;
      case 'sand':
        return Icons.grain;
      case 'iron rod':
        return Icons.hardware;
      default:
        return Icons.category_outlined;
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
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
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  void _submit() async {
    if (selectedCategoryObj == null) {
      _showSnack('Please select a category', isSuccess: false);
      return;
    }
    if (!isSandCategory() && selectedBrandObj == null) {
      _showSnack('Please select a brand', isSuccess: false);
      return;
    }
    if (selectedProductObj == null) {
      _showSnack('Please select a product', isSuccess: false);
      return;
    }
    if (priceController.text.trim().isEmpty) {
      _showSnack('Please enter price per unit', isSuccess: false);
      return;
    }
    if (stockController.text.trim().isEmpty) {
      _showSnack('Please enter available stock', isSuccess: false);
      return;
    }

    setState(() => isLoading = true);

    final response = await api.createListing(
      categoryId: selectedCategoryObj['id'] as int,
      brandId: selectedBrandObj?['id'] as int?, // null for Sand
      productId: selectedProductObj['id'] as int,
      pricePerunit: double.tryParse(priceController.text.trim()) ?? 0,
      deliveryChargePerTon:
          double.tryParse(deliveryController.text.trim()) ?? 0,
      stock: int.tryParse(stockController.text.trim()) ?? 0,
      riverSource: riverSourceController.text.trim().isEmpty
          ? null
          : riverSourceController.text.trim(),
    );

    setState(() => isLoading = false);

    if (response['success'] == true) {
      setState(() => showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => showSuccess = false);
      });
    } else {
      _showSnack(
        response['message'] ?? 'Failed to list product',
        isSuccess: false,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final product = selectedProductObj;

    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 3,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressBar(product),
                          const SizedBox(height: 24),

                          // Step 1 — Category
                          _stepCard(
                            step: 1,
                            title: 'Select Category',
                            child: _buildCategoryGrid(),
                          ),

                          // Step 2 — Brand (skip for Sand)
                          if (selectedCategory.isNotEmpty &&
                              !isSandCategory()) ...[
                            const SizedBox(height: 16),
                            _stepCard(
                              step: 2,
                              title: 'Select Brand',
                              child: _buildBrandList(),
                            ),
                          ],

                          // Step 2/3 — Product
                          if (isSandCategory()
                              ? products.isNotEmpty
                              : selectedBrand.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _stepCard(
                              step: isSandCategory() ? 2 : 3,
                              title: isSandCategory()
                                  ? 'Select Sand Type'
                                  : 'Select Product',
                              child: _buildProductList(),
                            ),
                          ],

                          // Auto-filled details + Pricing
                          if (product != null) ...[
                            const SizedBox(height: 16),
                            _buildProductDetailsCard(product),
                            const SizedBox(height: 16),
                            _stepCard(
                              step: isSandCategory() ? 3 : 4,
                              title: 'Set Your Pricing & Details',
                              child: _buildPricingFields(product),
                            ),
                            const SizedBox(height: 24),
                            _buildSubmitButton(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showSuccess) _buildSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.vendor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onSelectView(ViewType.vendorHome),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List New Product',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add product to marketplace',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress Bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar(dynamic product) {
    int completedSteps = 0;
    if (selectedCategory.isNotEmpty) completedSteps++;
    if (!isSandCategory() && selectedBrand.isNotEmpty) completedSteps++;
    if (selectedProduct.isNotEmpty) completedSteps++;
    if (product != null) completedSteps++;

    final steps = isSandCategory()
        ? ['Category', 'Product', 'Pricing']
        : ['Category', 'Brand', 'Product', 'Pricing'];

    return Row(
      children: List.generate(steps.length, (i) {
        final done = i < completedSteps;
        final active = i == completedSteps;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.vendor
                            : active
                            ? AppColors.vendor.withOpacity(0.3)
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: done || active
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: done
                            ? AppColors.vendor
                            : active
                            ? AppColors.titleText
                            : AppColors.subtleText,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  // ── Step Card ─────────────────────────────────────────────────────────────

  Widget _stepCard({
    required int step,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.vendor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleText,
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border.withOpacity(0.6), height: 24),
          child,
        ],
      ),
    );
  }

  // ── Category Grid ─────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            color: AppColors.vendor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: getCategories().map((category) {
        final selected = selectedCategory == category;
        return GestureDetector(
          onTap: () async {
            final categoryObj = categories.firstWhere(
              (c) => c['name'] == category,
            );
            setState(() {
              selectedCategory = category;
              selectedCategoryObj = categoryObj;
              selectedBrand = '';
              selectedProduct = '';
              selectedBrandObj = null;
              selectedProductObj = null;
              brands = [];
              products = [];
              riverSourceController.clear();
            });
            if (isSandCategory()) {
              await fetchProductsByCategory(categoryObj['id'] as int);
            } else {
              await fetchBrands(categoryObj['id'] as int);
            }
          },
          child: Container(
            width:
                (MediaQuery.of(context).size.width - 88) /
                getCategories().length,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.vendorMuted : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.vendor : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  getCategoryIcon(category),
                  size: 26,
                  color: selected ? AppColors.vendor : AppColors.bodyText,
                ),
                const SizedBox(height: 8),
                Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.vendor : AppColors.bodyText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Brand List ────────────────────────────────────────────────────────────

  Widget _buildBrandList() {
    if (brands.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            color: AppColors.vendor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      children: getBrands().map((brand) {
        final selected = selectedBrand == brand;
        return GestureDetector(
          onTap: () async {
            final brandObj = brands.firstWhere((b) => b['name'] == brand);
            setState(() {
              selectedBrand = brand;
              selectedBrandObj = brandObj;
              selectedProduct = '';
              selectedProductObj = null;
              products = [];
            });
            await fetchProducts(brandObj['id'] as int);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.vendorMuted : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.vendor : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 18,
                  color: selected ? AppColors.vendor : AppColors.bodyText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    brand,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.vendor : AppColors.titleText,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.vendor,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Product List ──────────────────────────────────────────────────────────

  Widget _buildProductList() {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            color: AppColors.vendor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      children: getProducts().map((p) {
        final selected = selectedProduct == p['id'].toString();
        return GestureDetector(
          onTap: () => setState(() {
            selectedProduct = p['id'].toString();
            selectedProductObj = p;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.vendorMuted : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.vendor : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.vendor
                        : AppColors.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: selected ? Colors.white : AppColors.bodyText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? AppColors.vendor
                              : AppColors.titleText,
                        ),
                      ),
                      if ((p['description'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.bodyText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.vendor,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Product Details Card ──────────────────────────────────────────────────

  Widget _buildProductDetailsCard(dynamic product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryMuted, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Auto-filled Product Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleText,
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border.withOpacity(0.6), height: 24),
          _detailRow('Product', product['name'] ?? ''),
          if (!isSandCategory())
            _detailRow('Brand', product['brand']?['name'] ?? ''),
          _detailRow('Unit', product['unit'] ?? ''),
          if ((product['description'] ?? '').isNotEmpty)
            _detailRow('Description', product['description']),
          if ((product['detailed_description'] ?? '').isNotEmpty)
            _detailRow('Details', product['detailed_description']),
          if ((product['specifications'] ?? []).isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Specifications',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.bodyText,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            ...(product['specifications'] as List).map(
              (spec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.vendorMuted,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: AppColors.vendor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spec['value'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.bodyText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtleText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.titleText,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pricing Fields ────────────────────────────────────────────────────────

  Widget _buildPricingFields(dynamic product) {
    final unit = product['unit'] ?? 'unit';
    return Column(
      children: [
        _pricingField(
          controller: priceController,
          label: 'Price per $unit',
          hint: 'e.g. 350',
          icon: Icons.currency_rupee_rounded,
          suffix: '₹',
        ),
        const SizedBox(height: 14),
        _pricingField(
          controller: deliveryController,
          label: 'Delivery charge per km',
          hint: 'e.g. 500',
          icon: Icons.local_shipping_outlined,
          suffix: '₹',
        ),
        const SizedBox(height: 14),
        _pricingField(
          controller: stockController,
          label: 'Available stock ($unit)',
          hint: 'e.g. 100',
          icon: Icons.inventory_2_outlined,
        ),

        // ── River Source (shown for all, but especially useful for Sand) ──
        // ── River Source (Sand only) ──
        if (isSandCategory()) ...[
          const SizedBox(height: 14),
          _pricingField(
            controller: riverSourceController,
            label: 'River source (optional)',
            hint: 'e.g. Mahanadi, Brahmani',
            icon: Icons.water_outlined,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: AppColors.subtleText),
              const SizedBox(width: 6),
              const Text(
                'River source helps buyers choose quality sand',
                style: TextStyle(fontSize: 11, color: AppColors.subtleText),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pricingField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.bodyText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.subtleText,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.vendor, size: 18),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: AppColors.bodyText,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.vendor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Submit Button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vendor,
          disabledBackgroundColor: AppColors.vendor.withOpacity(0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'List Product in Marketplace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Success Overlay ───────────────────────────────────────────────────────

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.vendorMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.vendor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Product Listed!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Successfully added to marketplace',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.bodyText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
