import 'package:flutter/material.dart';
import '../view_type.dart';
import '../services/api_service.dart'; // adjust path if needed

class CreateAccountPage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  final String userType; // 'customer' or 'vendor'

  const CreateAccountPage({
    super.key,
    required this.onSelectView,
    required this.userType,
  });

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();

  bool agreeTerms = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final firmNameController = TextEditingController();
  final businessTypeController = TextEditingController();
  final gstController = TextEditingController();

  // ===== ROLE LOGIC =====
  bool get isVendor => widget.userType == 'vendor';

  Color get primaryColor => isVendor ? Colors.green : const Color(0xFF1E5BFF);

  String get accountText =>
      isVendor ? "Create Vendor Account" : "Create Customer Account";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F7FB),
        leading: TextButton.icon(
          onPressed: () => widget.onSelectView(ViewType.landing),
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          label: const Text("Back"),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    "Sign up as a ${widget.userType}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),

                _label("Full Name"),
                _inputField(
                  controller: nameController,
                  hint: "John Doe",
                  icon: Icons.person_outline,
                ),

                _label("Email Address"),
                _inputField(
                  controller: emailController,
                  hint: "you@example.com",
                  icon: Icons.mail_outline,
                  keyboard: TextInputType.emailAddress,
                ),

                _label("Phone Number"),
                _inputField(
                  controller: phoneController,
                  hint: "+1 (555) 000-0000",
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                ),

                // ===== VENDOR EXTRA FIELDS =====
                if (isVendor) ...[
                  _label("Firm Name"),
                  _inputField(
                    controller: firmNameController,
                    hint: "ABC Traders Pvt Ltd",
                    icon: Icons.business,
                  ),

                  _label("Business Type"),
                  _inputField(
                    controller: businessTypeController,
                    hint: "Cement Supplier / Sand Dealer",
                    icon: Icons.category_outlined,
                  ),

                  _label("GST Number"),
                  _inputField(
                    controller: gstController,
                    hint: "22AAAAA0000A1Z5",
                    icon: Icons.receipt_long_outlined,
                  ),
                ],

                _label("Password"),
                _passwordField(
                  controller: passwordController,
                  hint: "Create a password",
                  obscure: obscurePassword,
                  toggle: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),

                _label("Confirm Password"),
                _passwordField(
                  controller: confirmPasswordController,
                  hint: "Confirm your password",
                  obscure: obscureConfirm,
                  toggle: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: agreeTerms,
                      activeColor: primaryColor,
                      onChanged: (value) => setState(() => agreeTerms = value!),
                    ),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 13),
                          children: [
                            TextSpan(text: "I agree to the "),
                            TextSpan(
                              text: "Terms of Service",
                              style: TextStyle(color: Colors.blue),
                            ),
                            TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: agreeTerms ? _handleSignup : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      accountText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black),
                      children: [
                        TextSpan(text: "Already have an account? "),
                        TextSpan(
                          text: "Sign in",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
        return;
      }

      // ===== EXTRA VALIDATION FOR VENDOR =====
      if (isVendor) {
        if (firmNameController.text.isEmpty ||
            businessTypeController.text.isEmpty ||
            gstController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all vendor details")),
          );
          return;
        }
      }

      final api = ApiService();

      final result = await api.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
        widget.userType,
        phoneController.text.trim(),

        // Pass extra vendor data
        firmName: isVendor ? firmNameController.text.trim() : null,
        businessType: isVendor ? businessTypeController.text.trim() : null,
        gstNumber: isVendor ? gstController.text.trim() : null,
      );

      if (!mounted) return;

      if (result["success"] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result["message"])));

        widget.onSelectView(ViewType.login, userType: widget.userType);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result["message"] ?? "Registration failed")),
        );
      }
    }
  }

  // ===== UI HELPERS =====
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }
}
