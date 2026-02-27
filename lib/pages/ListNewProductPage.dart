import 'package:flutter/material.dart';
import '../view_type.dart';
import '../services/api_service.dart';

class AddProductPage extends StatefulWidget {
  final Function(ViewType) onSelectView;

  const AddProductPage({super.key, required this.onSelectView});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
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

  final TextEditingController priceController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  final TextEditingController stockController = TextEditingController();

  bool showSuccess = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  // =============================
  // API CALLS
  // =============================

  Future<void> fetchCategories() async {
    try {
      categories = await api.getCategories();
      setState(() {});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load categories")),
      );
    }
  }

  Future<void> fetchBrands(int categoryId) async {
    brands = await api.getBrands(categoryId);
    setState(() {});
  }

  Future<void> fetchProducts(int brandId) async {
    products = await api.getProducts(brandId);
    setState(() {});
  }

  // =============================
  // FILTER METHODS (SAME UI STRUCTURE)
  // =============================

  List<String> getCategories() {
    return categories.map((c) => c["name"].toString()).toList();
  }

  List<String> getBrands() {
    if (selectedCategoryObj == null) return [];
    return brands.map((b) => b["name"].toString()).toList();
  }

  List<dynamic> getProducts() {
    if (selectedBrandObj == null) return [];
    return products;
  }

  dynamic getSelectedProduct() {
    return selectedProductObj;
  }

  String getCategoryIcon(String category) {
    if (category == "Cement") return "🏗️";
    if (category == "Sand") return "🏖️";
    if (category == "Iron Rod") return "⚒️";
    return "📦";
  }

  // =============================
  // SUBMIT
  // =============================

  void _submit() async {
    if (priceController.text.isEmpty ||
        deliveryController.text.isEmpty ||
        stockController.text.isEmpty ||
        selectedProductObj == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final response = await api.createListing(
      categoryId: selectedCategoryObj["id"],
      brandId: selectedBrandObj["id"],
      productId: selectedProductObj["id"],
      pricePerBag: double.parse(priceController.text),
      deliveryChargePerTon: double.parse(deliveryController.text),
      stock: int.parse(stockController.text),
    );

    if (response["success"]) {
      setState(() => showSuccess = true);

      Future.delayed(const Duration(seconds: 2), () {
        setState(() => showSuccess = false);
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response["message"])));
    }
  }

  // =============================
  // UI (UNCHANGED)
  // =============================

  @override
  Widget build(BuildContext context) {
    final product = getSelectedProduct();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 16),

                  /// CATEGORY
                  _stepCard(
                    step: "1",
                    title: "Select Category",
                    child: Row(
                      children: getCategories().map((category) {
                        final selected = selectedCategory == category;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final categoryObj = categories.firstWhere(
                                (c) => c["name"] == category,
                              );

                              selectedCategory = category;
                              selectedCategoryObj = categoryObj;
                              selectedBrand = '';
                              selectedProduct = '';
                              selectedBrandObj = null;
                              selectedProductObj = null;

                              await fetchBrands(categoryObj["id"]);
                              products = [];

                              setState(() {});
                            },
                            child: _categoryTile(
                              category,
                              getCategoryIcon(category),
                              selected,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  /// BRAND
                  if (selectedCategory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _stepCard(
                      step: "2",
                      title: "Select Brand",
                      child: Column(
                        children: getBrands().map((brand) {
                          final selected = selectedBrand == brand;
                          return _selectTile(brand, selected, () async {
                            final brandObj = brands.firstWhere(
                              (b) => b["name"] == brand,
                            );

                            selectedBrand = brand;
                            selectedBrandObj = brandObj;
                            selectedProduct = '';
                            selectedProductObj = null;

                            await fetchProducts(brandObj["id"]);
                            setState(() {});
                          });
                        }).toList(),
                      ),
                    ),
                  ],

                  /// PRODUCT
                  if (selectedBrand.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _stepCard(
                      step: "3",
                      title: "Select Product",
                      child: Column(
                        children: getProducts().map((p) {
                          final selected =
                              selectedProduct == p["id"].toString();
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedProduct = p["id"].toString();
                                selectedProductObj = p;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? Colors.green
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                                color: selected
                                    ? Colors.green.shade50
                                    : Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p["name"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p["description"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  /// DETAILS + PRICING (UNCHANGED DESIGN)
                  if (product != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.indigo.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Product Details (Auto-filled)",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          _detailBox("Product Name", product["name"]),
                          _detailBox("Brand", product["brand"]?["name"] ?? ""),
                          _detailBox(
                            "Description",
                            product["description"] ?? "",
                          ),
                          _detailBox(
                            "Detailed Description",
                            product["detailed_description"] ?? "",
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Specifications",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          ...(product["specifications"] ?? []).map<Widget>(
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
                          ),
                          const SizedBox(height: 8),
                          _detailBox("Unit", product["unit"] ?? ""),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stepCard(
                      step: "4",
                      title: "Enter Your Pricing",
                      child: Column(
                        children: [
                          _inputField(
                            controller: priceController,
                            hint: "Enter price per ${product["unit"] ?? ""}",
                            prefixIcon: Icons.currency_rupee,
                            suffix: "₹",
                          ),
                          const SizedBox(height: 12),
                          _inputField(
                            controller: deliveryController,
                            hint: "Delivery charge per ton",
                            prefixIcon: Icons.local_shipping,
                            suffix: "₹",
                          ),
                          const SizedBox(height: 12),
                          _inputField(
                            controller: stockController,
                            hint: "Available stock (${product["unit"] ?? ""})",
                            prefixIcon: Icons.inventory_2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.inventory),
                        label: const Text("List Product in Marketplace"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showSuccess) _successModal(),
        ],
      ),
    );
  }

  // ---- UI helpers unchanged ----

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => widget.onSelectView(ViewType.vendorHome),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "List New Product",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              "Add product to marketplace",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepCard({
    required String step,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.shade100,
                child: Text(step, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _categoryTile(String title, String icon, bool selected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
        color: selected ? Colors.green.shade50 : Colors.white,
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _selectTile(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade300,
            width: 2,
          ),
          color: selected ? Colors.green.shade50 : Colors.white,
        ),
        child: Text(title),
      ),
    );
  }

  Widget _detailBox(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7A7A7A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixIcon: Icon(prefixIcon),
        suffixText: suffix,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
    );
  }

  Widget _successModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 50),
              SizedBox(height: 12),
              Text(
                "Product Listed!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                "Successfully added to marketplace",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
