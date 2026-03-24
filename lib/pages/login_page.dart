import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import 'package:front/view_type.dart';
import 'package:front/services/session_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/logo.dart';

class LoginPage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  final String userType;

  const LoginPage({
    super.key,
    required this.onSelectView,
    required this.userType,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool obscurePassword = true;
  bool rememberMe = false;
  bool _isLoading = false;
  String _errorMessage = '';

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _api = ApiService();

  bool get isVendor => widget.userType == 'vendor';
  Color get _accent => isVendor ? const Color(0xFF15803D) : AppColors.primary;
  Color get _accentMuted =>
      isVendor ? const Color(0xFFF0FDF4) : AppColors.primaryMuted;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() => _errorMessage = "Please enter email and password");
      return;
    }
    if (!emailController.text.contains('@')) {
      setState(() => _errorMessage = "Enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await _api.login(
      emailController.text.trim(),
      passwordController.text,
      role: widget.userType,
    );

    setState(() => _isLoading = false);

    if (result["success"] == true) {
      final returnedRole = result["role"] as String?;

      if (returnedRole != widget.userType) {
        setState(
          () => _errorMessage =
              "You are registered as a $returnedRole, not as ${widget.userType}.",
        );
        return;
      }

      // ── Extract token from the nested "data" map that ApiService returns ──
      // ApiService already saved it via SharedPreferences but did NOT return
      // it at the top level. We dig it out of result["data"] here.
      final data = result["data"] as Map<String, dynamic>? ?? {};
      final token =
          (data["token"] ??
                  data["access_token"] ??
                  data["authorisation"]?["token"] ??
                  '')
              as String;

      // ── Persist session so refresh restores the page ──────────────────────
      await SessionManager.saveSession(
        token: token,
        userType: returnedRole!,
        expiryHours: rememberMe ? 720 : 24, // 30 days vs 1 day
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result["message"] ?? "Login successful"),
          backgroundColor: AppColors.success,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
      widget.onSelectView(
        isVendor ? ViewType.vendorHome : ViewType.customerHome,
      );
    } else {
      setState(
        () => _errorMessage = result["message"] ?? "Login failed. Try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ── Left panel (desktop only) ──────────────────────────────────
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
                    Positioned.fill(child: CustomPaint(painter: _DotPainter())),
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  ? "🚚  Vendor Portal"
                                  : "👷  Customer Portal",
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
                                ? "Welcome back,\nSupplier."
                                : "Welcome back,\nBuilder.",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isVendor
                                ? "Sign in to manage your orders,\ninventory and listings."
                                : "Sign in to browse materials\nand track your deliveries.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Divider(color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 20),
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => widget.onSelectView(ViewType.signup),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Create an account",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
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

          // ── Right panel: form ──────────────────────────────────────────
          Expanded(
            flex: isMobile ? 1 : 6,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 64,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          const SizedBox(height: 32),
                        ],

                        const Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.titleText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              "Signing in as a ",
                              style: TextStyle(
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

                        if (_errorMessage.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _errorMessage = ''),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        _fieldLabel("Email Address"),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: emailController,
                          hint: "you@example.com",
                          icon: Icons.mail_outline,
                          keyboard: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),

                        _fieldLabel("Password"),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.titleText,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter your password",
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
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.bodyText,
                              ),
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _accent,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: rememberMe,
                                activeColor: _accent,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (v) =>
                                    setState(() => rememberMe = v!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Remember me",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.bodyText,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  widget.onSelectView(ViewType.forgotPassword),
                              child: Text(
                                "Forgot password?",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
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
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.bodyText,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    widget.onSelectView(ViewType.signup),
                                child: Text(
                                  "Sign Up",
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

                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: () => widget.onSelectView(ViewType.landing),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 12,
                                  color: AppColors.subtleText,
                                ),
                                SizedBox(width: 4),
                                Text(
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
                      ],
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

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.titleText,
    ),
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    style: const TextStyle(fontSize: 14, color: AppColors.titleText),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.subtleText, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AppColors.bodyText),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    ),
  );
}

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
