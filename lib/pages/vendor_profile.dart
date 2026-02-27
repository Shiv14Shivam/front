import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_card.dart';
import '../widgets/info_tile.dart';
import '../widgets/location_card.dart';
import '../view_type.dart';
import '../services/api_service.dart';

class VendorProfilePage extends StatefulWidget {
  final Function(ViewType) onSelectView;

  const VendorProfilePage({super.key, required this.onSelectView});

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? user;
  Map<String, dynamic>? vendor;
  List<dynamic> addresses = [];
  bool isLoading = true;
  bool isEditing = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController firmController = TextEditingController();
  final TextEditingController businessTypeController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  // ================= SAFE YEAR FORMATTER =================
  // This safely extracts year from created_at
  // It will NEVER crash even if created_at is null or invalid
  String _getYear() {
    try {
      final createdAt = user?["created_at"];

      if (createdAt == null) return "";

      final date = DateTime.parse(createdAt.toString());
      return date.year.toString();
    } catch (e) {
      return ""; // if parsing fails, return empty instead of crashing
    }
  }

  Future<void> _loadVendorData() async {
    final profileRes = await _apiService.getProfile();
    final addressRes = await _apiService.getAddresses();

    if (profileRes["success"]) {
      user = profileRes["user"];
      vendor = user?["vendor"];

      nameController.text = user?["name"] ?? "";
      emailController.text = user?["email"] ?? "";
      phoneController.text = user?["phone"] ?? "";
      firmController.text = vendor?["firm_name"] ?? "";
      businessTypeController.text = vendor?["business_type"] ?? "";
      gstController.text = vendor?["gst_number"] ?? "";
    }

    if (addressRes["success"]) {
      addresses = List.from(addressRes["data"]);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final res = await _apiService.updateProfile(
      nameController.text,
      emailController.text,
      phoneController.text,
      firmName: firmController.text,
      businessType: businessTypeController.text,
      gstNumber: gstController.text,
    );

    if (res["success"]) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile Updated")));
      await _loadVendorData();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res["message"])));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 60),
            _buildStatsSection(),
            const SizedBox(height: 20),
            _buildBusinessInfoSection(),
            const SizedBox(height: 20),
            _buildBusinessLocationsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 16,
          child: GestureDetector(
            onTap: () => widget.onSelectView(ViewType.vendorHome),
            child: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.08),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 35,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor?["firm_name"] ?? user?["name"] ?? "",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor?["business_type"] ??
                            "Construction Materials Supplier",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [Chip(label: Text("Since ${_getYear()}"))]),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (isEditing) {
                      await _saveProfile();
                    }
                    setState(() {
                      isEditing = !isEditing;
                    });
                  },
                  child: Icon(
                    isEditing ? Icons.check : Icons.edit,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= STATS =================

  Widget _buildStatsSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatCard(icon: Icons.inventory, value: "248", label: "Products"),
          StatCard(icon: Icons.star, value: "4.8", label: "Rating"),
          StatCard(icon: Icons.trending_up, value: "1.2K", label: "Orders"),
        ],
      ),
    );
  }

  // ================= BUSINESS INFO =================

  Widget _buildBusinessInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: "Business Information",
        icon: Icons.business,
        children: [
          isEditing
              ? _editableField("Business Name", firmController)
              : InfoTile(
                  title: "Business Name",
                  value: vendor?["firm_name"] ?? "",
                ),
          isEditing
              ? _editableField("Owner Name", nameController)
              : InfoTile(title: "Owner Name", value: user?["name"] ?? ""),
          isEditing
              ? _editableField("Email", emailController)
              : InfoTile(title: "Email", value: user?["email"] ?? ""),
          isEditing
              ? _editableField("Phone", phoneController)
              : InfoTile(title: "Phone", value: user?["phone"] ?? ""),
          isEditing
              ? _editableField("GST Number", gstController)
              : InfoTile(
                  title: "GST Number",
                  value: vendor?["gst_number"] ?? "N/A",
                ),
          isEditing
              ? _editableField("Business Type", businessTypeController)
              : InfoTile(
                  title: "Business Type",
                  value: vendor?["business_type"] ?? "Supplier",
                ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ================= LOCATIONS =================

  Widget _buildBusinessLocationsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: "Business Locations",
        icon: Icons.location_on,
        showAdd: true,
        onAddTap: () {
          widget.onSelectView(ViewType.addressForm);
        },
        children: addresses.isEmpty
            ? [const Text("No addresses found")]
            : addresses.map((address) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LocationCard(
                    title: address["label"] ?? "Location",
                    address:
                        "${address["address_line_1"]}\n${address["city"]}, ${address["state"]} - ${address["pincode"]}",
                    isDefault: address["is_default"] == true,
                  ),
                );
              }).toList(),
      ),
    );
  }
}
