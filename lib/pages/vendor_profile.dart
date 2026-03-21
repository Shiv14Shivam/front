import 'package:flutter/material.dart';
import '../view_type.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/web_scaffold.dart';

class VendorProfilePage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  const VendorProfilePage({super.key, required this.onSelectView});

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? user;
  Map<String, dynamic>? vendor;
  List<dynamic> addresses = [];
  bool isLoading = true;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final firmController = TextEditingController();
  final businessTypeController = TextEditingController();
  final gstController = TextEditingController();
  final emailController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadVendorData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    nameController.dispose();
    phoneController.dispose();
    firmController.dispose();
    businessTypeController.dispose();
    gstController.dispose();
    emailController.dispose();
    super.dispose();
  }

  String _getYear() {
    try {
      final createdAt = user?["created_at"];
      if (createdAt == null) return "";
      return DateTime.parse(createdAt.toString()).year.toString();
    } catch (_) {
      return "";
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

    if (mounted) {
      setState(() => isLoading = false);
      _fadeController.forward();
    }
  }

  // ── Edit dialog (same pattern as CustomerProfilePage) ─────────────────────
  void _showEditDialog() {
    final nameEdit = TextEditingController(text: nameController.text);
    final emailEdit = TextEditingController(text: emailController.text);
    final phoneEdit = TextEditingController(text: phoneController.text);
    final firmEdit = TextEditingController(text: firmController.text);
    final businessEdit = TextEditingController(
      text: businessTypeController.text,
    );
    final gstEdit = TextEditingController(text: gstController.text);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
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
              // Dialog header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.vendor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Edit Business Profile",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable fields
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildTextField(
                        firmEdit,
                        "Firm Name",
                        Icons.business_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        nameEdit,
                        "Owner Name",
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        emailEdit,
                        "Email Address",
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        phoneEdit,
                        "Phone Number",
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        gstEdit,
                        "GST Number",
                        Icons.receipt_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        businessEdit,
                        "Business Type",
                        Icons.category_outlined,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOutlinedButton(
                              "Cancel",
                              () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrimaryButton("Save", () async {
                              Navigator.pop(context);
                              final res = await _apiService.updateProfile(
                                nameEdit.text.trim(),
                                emailEdit.text.trim(),
                                phoneEdit.text.trim(),
                                firmName: firmEdit.text.trim(),
                                businessType: businessEdit.text.trim(),
                                gstNumber: gstEdit.text.trim(),
                              );
                              if (res["success"] && mounted) {
                                _showSnack(
                                  "Profile updated successfully",
                                  isSuccess: true,
                                );
                                await _loadVendorData();
                              } else if (mounted) {
                                _showSnack(
                                  res["message"] ?? "Update failed",
                                  isSuccess: false,
                                );
                              }
                            }),
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
    ).then((_) {
      nameEdit.dispose();
      emailEdit.dispose();
      phoneEdit.dispose();
      firmEdit.dispose();
      businessEdit.dispose();
      gstEdit.dispose();
    });
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return WebScaffold(
        isVendor: true,
        onSelectView: widget.onSelectView,
        selectedIndex: 5,
        body: const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppColors.vendor,
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  "Loading...",
                  style: TextStyle(color: AppColors.bodyText, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 5,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      _buildBusinessInfoCard(),
                      const SizedBox(height: 20),
                      _buildLocationsCard(),
                      const SizedBox(height: 28),
                      _buildLogoutButton(),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.vendor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _headerIconBtn(
                    Icons.arrow_back_ios_new_rounded,
                    () => widget.onSelectView(ViewType.vendorHome),
                  ),
                  const Spacer(),
                  const Text(
                    "Vendor Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // ✅ Always shows edit icon; opens dialog on tap
                  _headerIconBtn(Icons.edit_outlined, _showEditDialog),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firmController.text.isNotEmpty
                              ? firmController.text
                              : nameController.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          businessTypeController.text.isNotEmpty
                              ? businessTypeController.text
                              : "Construction Supplier",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_getYear().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        "Since ${_getYear()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
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
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(Icons.inventory_2_outlined, "248", "Products"),
        const SizedBox(width: 12),
        _statCard(Icons.star_outline_rounded, "4.8", "Rating"),
        const SizedBox(width: 12),
        _statCard(Icons.trending_up_rounded, "1.2K", "Orders"),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.vendor, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.bodyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Business Info Card (read-only now — edit via dialog) ───────────────────
  Widget _buildBusinessInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Business Information"),
              GestureDetector(
                onTap: _showEditDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.vendor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text(
                        "Edit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.business_outlined, "Firm Name", firmController.text),
          _divider(),
          _infoRow(Icons.person_outline, "Owner Name", nameController.text),
          _divider(),
          _infoRow(Icons.email_outlined, "Email Address", emailController.text),
          _divider(),
          _infoRow(Icons.phone_outlined, "Phone Number", phoneController.text),
          _divider(),
          _infoRow(Icons.receipt_outlined, "GST Number", gstController.text),
          _divider(),
          _infoRow(
            Icons.category_outlined,
            "Business Type",
            businessTypeController.text,
          ),
        ],
      ),
    );
  }

  // ── Locations Card ─────────────────────────────────────────────────────────
  Widget _buildLocationsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Business Locations"),
              GestureDetector(
                onTap: () => widget.onSelectView(ViewType.addressForm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.vendor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Add New",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (addresses.isEmpty)
            _emptyState(
              Icons.location_on_outlined,
              "No locations added",
              "Add your first business address",
            )
          else
            ...addresses.map((a) => _locationTile(a)),
        ],
      ),
    );
  }

  Widget _locationTile(dynamic address) {
    final isDefault = address["is_default"] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.vendor.withOpacity(0.04)
            : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault
              ? AppColors.vendor.withOpacity(0.3)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDefault
                  ? AppColors.vendor.withOpacity(0.1)
                  : AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDefault ? Icons.star_rounded : Icons.location_on_outlined,
              size: 16,
              color: isDefault ? AppColors.vendor : AppColors.bodyText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address["label"] ?? "Location",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDefault
                              ? AppColors.vendor
                              : AppColors.titleText,
                        ),
                      ),
                    ),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.vendor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Default",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${address["address_line_1"]}\n${address["city"]}, ${address["state"]} - ${address["pincode"]}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final res = await _apiService.logout();
          if (res["success"] && mounted) {
            widget.onSelectView(ViewType.login);
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          "Sign Out",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.5), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.bodyText,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.vendor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? "Not provided" : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? AppColors.bodyText
                        : AppColors.titleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    color: AppColors.border.withOpacity(0.6),
  );

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.titleText,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.bodyText),
        prefixIcon: Icon(icon, color: AppColors.vendor, size: 18),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.vendor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vendor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(String text, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bodyText,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
