import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';
import '../widgets/web_layout.dart'; // ✅ added

class RequestOrderPage extends StatefulWidget {
  final Function(ViewType, {String? userType, Map<String, dynamic>? orderData})
  onSelectView;
  final dynamic listing;
  final double quantity;
  final double distance;
  final double totalCost;

  const RequestOrderPage({
    super.key,
    required this.onSelectView,
    required this.listing,
    required this.quantity,
    required this.distance,
    required this.totalCost,
  });

  @override
  State<RequestOrderPage> createState() => _RequestOrderPageState();
}

class _RequestOrderPageState extends State<RequestOrderPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController noteController = TextEditingController();

  List<dynamic> savedAddresses = [];
  dynamic selectedAddress;

  bool isLoadingAddresses = true;
  bool isSubmitting = false;
  bool orderPlaced = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => isLoadingAddresses = true);

    try {
      final res = await _apiService.getAddresses();

      if (res["success"]) {
        final list = List<dynamic>.from(res["data"] ?? []);

        setState(() {
          savedAddresses = list;
          selectedAddress = list.firstWhere(
            (a) => a["is_default"] == true,
            orElse: () => list.isNotEmpty ? list.first : null,
          );
        });
      }
    } catch (_) {}

    setState(() => isLoadingAddresses = false);
  }

  Future<void> placeDirectOrder() async {
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a delivery address")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final result = await _apiService.placeDirectOrder(
      listingId: widget.listing["id"],
      quantityunit: widget.quantity.toInt(),
      deliveryAddressId: selectedAddress["id"],
      notes: noteController.text.trim(),
    );

    setState(() => isSubmitting = false);

    if (result["success"]) {
      setState(() => orderPlaced = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Failed to place order")),
      );
    }
  }

  String _formatAddress(dynamic address) {
    return [
      address["address_line_1"] ?? "",
      address["address_line_2"] ?? "",
      "${address["city"] ?? ""}, ${address["state"] ?? ""}",
      address["pincode"] ?? "",
    ].where((s) => s.trim().isNotEmpty).join(", ");
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ✅ WebLayout used (not WebScaffold) — this is a standalone flow page
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (orderPlaced) return _orderSuccessScreen();

    final product = widget.listing["product"];
    final seller = widget.listing["seller"];

    final pricePerunit =
        double.tryParse(widget.listing["price_per_unit"].toString()) ?? 0;

    final deliveryCharge =
        double.tryParse(widget.listing["delivery_charge_per_km"].toString()) ??
        0;

    final materialCost = widget.quantity * pricePerunit;
    final deliveryCost = widget.distance * deliveryCharge;

    return WebLayout(
      maxWidth: 720, // order form looks best at medium width
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => widget.onSelectView(ViewType.customerHome),
          ),
          title: const Text(
            "Request Order",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// ORDER SUMMARY
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Order Summary", Icons.receipt_long),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EEF7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "🏗️",
                            style: TextStyle(fontSize: 30),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product["name"] ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product["short_description"] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    _summaryRow(
                      "Quantity",
                      "${widget.quantity} ${product["unit"] ?? "unit"}",
                    ),
                    _summaryRow("Distance", "${widget.distance} km"),
                    _summaryRow("Price per unit", "₹$pricePerunit"),
                    _summaryRow(
                      "Material Cost",
                      "₹${materialCost.toStringAsFixed(2)}",
                    ),
                    _summaryRow(
                      "Delivery Charges",
                      "₹${deliveryCost.toStringAsFixed(2)}",
                    ),

                    const Divider(),

                    _summaryRow(
                      "Total Cost",
                      "₹${widget.totalCost.toStringAsFixed(2)}",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// SELLER DETAILS
              _sectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.store, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seller["name"] ?? "",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          seller["phone"] ?? "",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// DELIVERY ADDRESS
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Delivery Address", Icons.location_on),
                    const SizedBox(height: 14),

                    if (isLoadingAddresses)
                      const Center(child: CircularProgressIndicator())
                    else
                      ...savedAddresses.map((address) {
                        final isSelected =
                            selectedAddress?["id"] == address["id"];

                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedAddress = address),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address["label"] ?? "Home",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatAddress(address),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// NOTE
              _sectionCard(
                child: TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "Additional note (optional)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              /// PLACE ORDER BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : placeDirectOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Place Order · ₹${widget.totalCost.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderSuccessScreen() {
    return WebLayout(
      maxWidth: 480,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Order Placed!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your order has been placed successfully.",
                style: TextStyle(color: AppColors.bodyText, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => widget.onSelectView(ViewType.customerHome),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Back to Marketplace",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
