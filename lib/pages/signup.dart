import 'package:flutter/material.dart';
import '../view_type.dart';
import '../theme/app_colors.dart';
import '../widgets/logo.dart';
import '../services/api_service.dart';

class CreateAccountPage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  final String userType;

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

  bool get isVendor => widget.userType == 'vendor';

  // Role-specific accent — vendor = green, customer = blue
  Color get _accent => isVendor ? const Color(0xFF15803D) : AppColors.primary;

  Color get _accentMuted =>
      isVendor ? const Color(0xFFF0FDF4) : AppColors.primaryMuted;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Row(
        children: [
          // ── Left panel (desktop only) ─────────────────────────────────────
          if (!isMobile)
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isVendor
                        ? [const Color(0xFF15803D), const Color(0xFF14532D)]
                        : [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Dot texture
                    Positioned.fill(child: CustomPaint(painter: _DotPainter())),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo
                          Row(
                            children: [
                              const AppLogo(size: 40),
                              const SizedBox(width: 10),
                              const Text(
                                "Sand Here",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isVendor
                                  ? "🚚  Vendor Account"
                                  : "👷  Customer Account",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isVendor
                                ? "Start supplying\nto builders\nacross India."
                                : "Order cement,\nsand & steel\nwith ease.",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isVendor
                                ? "List your products, manage orders and grow your business on Sand Here."
                                : "Browse verified suppliers and get materials delivered straight to your site.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Feature bullets
                          ...(isVendor
                                  ? [
                                      "List products & set pricing",
                                      "Manage orders & inventory",
                                      "Reach more customers",
                                    ]
                                  : [
                                      "Browse verified vendors",
                                      "Order any material easily",
                                      "Track delivery live",
                                    ])
                              .map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        f,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right panel: form ─────────────────────────────────────────────
          Expanded(
            flex: isMobile ? 1 : 6,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 56,
                  vertical: 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Mobile logo ──────────────────────────────────
                          if (isMobile) ...[
                            Row(
                              children: [
                                const AppLogo(size: 32),
                                const SizedBox(width: 8),
                                const Text(
                                  "Sand Here",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.titleText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                          ],

                          // ── Header ───────────────────────────────────────
                          Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.titleText,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                "Signing up as a ",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.bodyText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentMuted,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(
                                  widget.userType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // ── Section: Personal Info ───────────────────────
                          _sectionLabel("Personal Info"),
                          const SizedBox(height: 12),
                          _field(
                            label: "Full Name",
                            controller: nameController,
                            hint: "Name",
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            label: "Email Address",
                            controller: emailController,
                            hint: "you@example.com",
                            icon: Icons.mail_outline,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            label: "Phone Number",
                            controller: phoneController,
                            hint: "+91 98765 43210",
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),

                          // ── Section: Vendor Business Info ────────────────
                          if (isVendor) ...[
                            const SizedBox(height: 28),
                            _sectionLabel("Business Info"),
                            const SizedBox(height: 12),
                            _field(
                              label: "Firm Name",
                              controller: firmNameController,
                              hint: "ABC Traders Pvt Ltd",
                              icon: Icons.business_outlined,
                            ),
                            const SizedBox(height: 14),
                            _field(
                              label: "Business Type",
                              controller: businessTypeController,
                              hint: "Cement Supplier / Sand Dealer",
                              icon: Icons.category_outlined,
                            ),
                            const SizedBox(height: 14),
                            _field(
                              label: "GST Number",
                              controller: gstController,
                              hint: "22AAAAA0000A1Z5",
                              icon: Icons.receipt_long_outlined,
                            ),
                          ],

                          // ── Section: Password ────────────────────────────
                          const SizedBox(height: 28),
                          _sectionLabel("Security"),
                          const SizedBox(height: 12),
                          _passwordField(
                            label: "Password",
                            controller: passwordController,
                            hint: "Create a strong password",
                            obscure: obscurePassword,
                            toggle: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _passwordField(
                            label: "Confirm Password",
                            controller: confirmPasswordController,
                            hint: "Re-enter your password",
                            obscure: obscureConfirm,
                            toggle: () => setState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),

                          // ── Terms ────────────────────────────────────────
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: agreeTerms,
                                  activeColor: _accent,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => agreeTerms = v!),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.bodyText,
                                    ),
                                    children: [
                                      const TextSpan(text: "I agree to the "),
                                      TextSpan(
                                        text: "Terms of Service",
                                        style: TextStyle(
                                          color: _accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(text: " and "),
                                      TextSpan(
                                        text: "Privacy Policy",
                                        style: TextStyle(
                                          color: _accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Submit button ────────────────────────────────
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: agreeTerms ? _handleSignup : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                disabledBackgroundColor: _accent.withOpacity(
                                  0.35,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isVendor
                                    ? "Create Vendor Account"
                                    : "Create Customer Account",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // ── Sign in link ─────────────────────────────────
                          const SizedBox(height: 20),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Already have an account? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.bodyText,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => widget.onSelectView(
                                    ViewType.login,
                                    userType: widget.userType,
                                  ),
                                  child: Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Back link ────────────────────────────────────
                          const SizedBox(height: 12),
                          Center(
                            child: GestureDetector(
                              onTap: () =>
                                  widget.onSelectView(ViewType.landing),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_back_ios,
                                    size: 12,
                                    color: AppColors.subtleText,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "Back to home",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.subtleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logic ──────────────────────────────────────────────────────────────────
  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      _snack("Passwords do not match");
      return;
    }
    if (isVendor &&
        (firmNameController.text.isEmpty ||
            businessTypeController.text.isEmpty ||
            gstController.text.isEmpty)) {
      _snack("Please fill all vendor details");
      return;
    }

    final api = ApiService();
    final result = await api.register(
      nameController.text.trim(),
      emailController.text.trim(),
      passwordController.text,
      widget.userType,
      phoneController.text.trim(),
      firmName: isVendor ? firmNameController.text.trim() : null,
      businessType: isVendor ? businessTypeController.text.trim() : null,
      gstNumber: isVendor ? gstController.text.trim() : null,
    );

    if (!mounted) return;

    if (result["success"] == true) {
      _snack(result["message"]);
      widget.onSelectView(ViewType.login, userType: widget.userType);
    } else {
      _snack(result["message"] ?? "Registration failed");
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Form helpers ───────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _accent,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 14, color: AppColors.titleText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.subtleText,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.bodyText),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _accent, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          validator: (v) => v!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: AppColors.titleText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.subtleText,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.bodyText,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.bodyText,
              ),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _accent, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          validator: (v) => v!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }
}

// Dot texture painter (reused from landing page style)
class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.1);
    const s = 28.0;
    for (double x = s; x < size.width; x += s)
      for (double y = s; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
