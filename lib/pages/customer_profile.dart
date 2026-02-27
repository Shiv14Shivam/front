import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';

class CustomerProfilePage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  const CustomerProfilePage({required this.onSelectView, super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  List<dynamic> addresses = [];
  bool isLoading = true;

  late AnimationController _gradientController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchData();
  }

  void _initializeAnimations() {
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);

    try {
      final profile = await _apiService.getProfile();
      final addressRes = await _apiService.getAddresses();

      if (profile["success"]) {
        final user = profile["user"];
        nameController.text = user["name"] ?? "";
        emailController.text = user["email"] ?? "";
        phoneController.text = user["phone"] ?? "";
      }

      if (addressRes["success"]) {
        addresses = List<dynamic>.from(addressRes["data"] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load data: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> logoutUser() async {
    try {
      final result = await _apiService.logout();
      if (result["success"]) {
        widget.onSelectView(ViewType.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Logout failed")));
      }
    }
  }

  void showEditProfileDialog() {
    final nameEdit = TextEditingController(text: nameController.text);
    final emailEdit = TextEditingController(text: emailController.text);
    final phoneEdit = TextEditingController(text: phoneController.text);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.primary,
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Text(
                      "Edit Profile",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildPremiumTextField(nameEdit, "Full Name", Icons.person),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(emailEdit, "Email", Icons.email),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(phoneEdit, "Mobile", Icons.phone),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumButton(
                            "Cancel",
                            () => Navigator.pop(context),
                            isSecondary: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          key: ValueKey(_pulseController.hashCode),
                          child: _buildPremiumButton("Save Changes", () async {
                            Navigator.pop(context);

                            final result = await _apiService.updateProfile(
                              nameEdit.text.trim(),
                              emailEdit.text.trim(),
                              phoneEdit.text.trim(),
                            );

                            if (result["success"] && mounted) {
                              setState(() {
                                nameController.text = nameEdit.text.trim();
                                emailController.text = emailEdit.text.trim();
                                phoneController.text = phoneEdit.text.trim();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Profile updated successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: StadiumBorder(),
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result["message"] ?? "Update failed",
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: StadiumBorder(),
                                ),
                              );
                            }
                          }),
                        ),
                      ],
                    ),
                  ],
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
    });
  }

  Widget _buildPremiumTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
          labelStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                _buildPremiumHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        _buildPremiumProfileCard(),
                        const SizedBox(height: 28),
                        _buildPremiumAddressSection(),
                        const SizedBox(height: 28),
                        _buildPremiumMenuCard(),
                        const SizedBox(height: 36),
                        _buildPremiumLogoutButton(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              "Loading Profile...",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gradientController,
        _shimmerController,
        _pulseController,
      ]),
      builder: (context, child) {
        return Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.primary.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.08),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () =>
                                widget.onSelectView(ViewType.customerHome),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Text(
                          "My Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumProfileCard() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 35,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildPremiumAvatar(),
                  const Spacer(),
                  _buildEditButton(),
                ],
              ),
              const SizedBox(height: 32),
              _buildDetailRow("Full Name", nameController.text, Icons.person),
              const SizedBox(height: 20),
              _buildDetailRow(
                "Email Address",
                emailController.text,
                Icons.email,
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                "Mobile Number",
                phoneController.text,
                Icons.phone,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.06),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Center(
              child: Text(
                nameController.text.isNotEmpty
                    ? nameController.text[0].toUpperCase()
                    : "U",
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextButton.icon(
            onPressed: showEditProfileDialog,
            icon: Icon(Icons.edit, size: 20, color: AppColors.primary),
            label: Text(
              "Edit Profile",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            value.isEmpty ? "Not provided" : value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumAddressSection() {
    return _buildPremiumCard(
      title: "📍 Delivery Addresses",
      action: _buildAddAddressButton(),
      children: addresses.isEmpty
          ? [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No addresses added yet",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add your first delivery address",
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ]
          : addresses
                .map((address) => _buildPremiumAddressTile(address))
                .toList(),
    );
  }

  Widget _buildAddAddressButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.03),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () async {
                widget.onSelectView(ViewType.addressForm);
                await Future.delayed(const Duration(milliseconds: 500));
                fetchData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Add New",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumAddressTile(dynamic address) {
    final isDefault = address["is_default"] == true;
    final lines = [
      address["address_line_1"] ?? "",
      address["address_line_2"] ?? "",
      "${address["city"] ?? ""}, ${address["state"] ?? ""}",
      address["pincode"] ?? "",
    ].where((line) => line.isNotEmpty).join(", ");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: isDefault
            ? Border.all(color: AppColors.primary, width: 2.5)
            : Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDefault
                ? AppColors.primary.withOpacity(0.25)
                : Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
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
                  color: isDefault ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isDefault ? Icons.star : Icons.location_on,
                  color: isDefault ? Colors.white : Colors.grey[700],
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  address["label"] ?? "Home",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "DEFAULT",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              lines,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isDefault)
                _buildActionButton(
                  "Set Default",
                  Icons.star_border_outlined,
                  const Color(0xFFF59E0B),
                  () async {
                    await _apiService.setDefaultAddress(address["id"]);
                    fetchData();
                  },
                ),
              const SizedBox(width: 12),
              _buildActionButton(
                "Remove",
                Icons.delete_outline,
                Colors.red,
                () async {
                  await _apiService.deleteAddress(address["id"]);
                  fetchData();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildPremiumMenuCard() {
    return _buildPremiumCard(
      title: "⚡ Quick Actions",
      children: [
        _buildPremiumMenuTile(Icons.receipt_long_outlined, "Order History"),
        _buildPremiumMenuTile(
          Icons.card_giftcard_outlined,
          "Rewards & Benefits",
        ),
        _buildPremiumMenuTile(Icons.support_agent_outlined, "Help & Support"),
        _buildPremiumMenuTile(Icons.settings_outlined, "Account Settings"),
      ],
    );
  }

  Widget _buildPremiumMenuTile(IconData icon, String title) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$title tapped!"),
                    duration: const Duration(milliseconds: 800),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumLogoutButton() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: logoutUser,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 40,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.red.shade400, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade600, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      "Sign Out",
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumButton(
    String text,
    VoidCallback onPressed, {
    bool isSecondary = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.02),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSecondary ? Colors.grey.shade300 : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: (isSecondary ? Colors.grey : AppColors.primary)
                      .withOpacity(isSecondary ? 0.3 : 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onPressed,
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSecondary ? Colors.grey[800] : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumCard({
    required String title,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (action != null) action,
              ],
            ),
          if (title.isNotEmpty) const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
