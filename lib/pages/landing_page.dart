import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/logo.dart';
import '../view_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SandHereWebsite  —  Landing page (Customer + Vendor focused)
//  Usage in main.dart:
//    case ViewType.primary:
//    case ViewType.landing:
//      child = SandHereWebsite(onSelectView: setView);
// ─────────────────────────────────────────────────────────────────────────────
class SandHereWebsite extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  const SandHereWebsite({super.key, required this.onSelectView});

  @override
  State<SandHereWebsite> createState() => _SandHereWebsiteState();
}

class _SandHereWebsiteState extends State<SandHereWebsite> {
  bool _showRoleModal = false;
  void _openModal() => setState(() => _showRoleModal = true);
  void _closeModal() => setState(() => _showRoleModal = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _Navbar(onGetStarted: _openModal),
                _HeroSection(onGetStarted: _openModal),
                _DualRoleSection(onGetStarted: _openModal),
                _CustomerBenefitsSection(),
                _VendorBenefitsSection(),
                _HowItWorksSection(),
                _FeaturesSection(),
                _CTASection(onGetStarted: _openModal),
                _Footer(),
              ],
            ),
          ),
          if (_showRoleModal)
            _RoleModal(
              onClose: _closeModal,
              onSelect: (userType) {
                _closeModal();
                widget.onSelectView(ViewType.login, userType: userType);
              },
            ),
        ],
      ),
    );
  }
}

// ─── NAVBAR ──────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _Navbar({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const AppLogo(size: 38),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "Sand",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.titleText,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: " Here",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            _NavLink("For Customers"),
            _NavLink("For Vendors"),
            _NavLink("How it works"),
            const SizedBox(width: 16),
          ],
          _GradientBtn(
            label: "Get Started",
            onTap: onGetStarted,
            small: isMobile,
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  const _NavLink(this.label);
  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        widget.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _hov ? AppColors.primary : AppColors.bodyText,
        ),
      ),
    ),
  );
}

// ─── HERO SECTION ────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF1565a0), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 28 : 80,
        vertical: isMobile ? 60 : 90,
      ),
      child: isMobile
          ? _HeroMobile(onGetStarted: onGetStarted)
          : _HeroDesktop(onGetStarted: onGetStarted),
    );
  }
}

class _HeroDesktop extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroDesktop({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Text(
                  "🏗️  Cement · Sand · Steel — All in one place",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                "Construction Materials,\nDelivered Fast.",
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.08,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Buy directly from verified suppliers. Sell to verified buyers.\nOne platform for the entire construction supply chain.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  _WhiteBtn(label: "Order as Customer", onTap: onGetStarted),
                  const SizedBox(width: 14),
                  _OutlineWhiteBtn(
                    label: "Supply as Vendor",
                    onTap: onGetStarted,
                  ),
                ],
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
        const SizedBox(width: 60),
        Expanded(flex: 45, child: _HeroVisual()),
      ],
    );
  }
}

class _HeroMobile extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroMobile({required this.onGetStarted});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Text(
          "🏗️  Cement · Sand · Steel",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        "Construction Materials,\nDelivered Fast.",
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.1,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        "Buy & sell construction materials in one place.",
        style: TextStyle(
          fontSize: 15,
          color: Colors.white.withOpacity(0.85),
          height: 1.6,
        ),
      ),
      const SizedBox(height: 28),
      _WhiteBtn(
        label: "Order as Customer",
        onTap: onGetStarted,
        fullWidth: true,
      ),
      const SizedBox(height: 10),
      _OutlineWhiteBtn(
        label: "Supply as Vendor",
        onTap: onGetStarted,
        fullWidth: true,
      ),
      const SizedBox(height: 36),
      _HeroVisual(),
      const SizedBox(height: 32),
      _StatsRow(),
    ],
  );
}

class _HeroVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotPainter())),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 88),
                const SizedBox(height: 20),
                Text(
                  "Sand Here",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Buy. Sell. Build.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF15803D),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        "Delivery in 24-48 hrs",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.titleText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.12);
    const s = 26.0;
    for (double x = s; x < size.width; x += s)
      for (double y = s; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 36,
    runSpacing: 16,
    children: [
      _Stat(value: "500+", label: "Orders"),
      _Stat(value: "50+", label: "Vendors"),
      _Stat(value: "4.9★", label: "Avg Rating"),
    ],
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
      ),
    ],
  );
}

// ─── DUAL ROLE SECTION ────────────────────────────────────────────────────────
class _DualRoleSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _DualRoleSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: const Color(0xFFF8FAFF),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 72,
      ),
      child: Column(
        children: [
          const Text(
            "One Platform, Two Roles",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Whether you're building or supplying — Sand Here connects you.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 48),
          isMobile
              ? Column(
                  children: [
                    _RoleFeatureCard(isVendor: false, onTap: onGetStarted),
                    const SizedBox(height: 20),
                    _RoleFeatureCard(isVendor: true, onTap: onGetStarted),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _RoleFeatureCard(
                        isVendor: false,
                        onTap: onGetStarted,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _RoleFeatureCard(
                        isVendor: true,
                        onTap: onGetStarted,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _RoleFeatureCard extends StatefulWidget {
  final bool isVendor;
  final VoidCallback onTap;
  const _RoleFeatureCard({required this.isVendor, required this.onTap});
  @override
  State<_RoleFeatureCard> createState() => _RoleFeatureCardState();
}

class _RoleFeatureCardState extends State<_RoleFeatureCard> {
  bool _hov = false;

  Color get _color => isVendor ? const Color(0xFF15803D) : AppColors.primary;

  Color get _muted =>
      isVendor ? const Color(0xFFF0FDF4) : AppColors.primaryMuted;

  bool get isVendor => widget.isVendor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _hov ? _muted : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hov ? _color.withOpacity(0.5) : AppColors.border,
              width: _hov ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _hov
                    ? _color.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _hov ? 28 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isVendor
                      ? Icons.local_shipping_rounded
                      : Icons.shopping_bag_rounded,
                  color: _color,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isVendor ? "I'm a Vendor" : "I'm a Customer",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _color,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVendor
                    ? "List, manage & deliver products. Grow your supply business with our mini ERP platform."
                    : "Browse certified suppliers. Order materials with confidence. Track delivery in real-time.",
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.bodyText,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 24),
              ...(isVendor
                      ? [
                          "Mini ERP to manage inventory",
                          "Analytics & revenue insights",
                          "Direct customer orders",
                        ]
                      : [
                          "Find verified suppliers",
                          "Price negotiation tools",
                          "Real-time order tracking",
                        ])
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check, color: _color, size: 11),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            f,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.bodyText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isVendor ? "Start Supplying →" : "Start Ordering →",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
}

// ─── CUSTOMER BENEFITS SECTION ────────────────────────────────────────────────
class _CustomerBenefitsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 72,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              "👤 For Customers",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Browse, Compare & Order",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Access verified suppliers, negotiate prices, and track delivery.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: isMobile ? 4.0 : 1.6,
            children: const [
              _BenefitCard(
                icon: Icons.verified_outlined,
                color: AppColors.primary,
                title: "Verified Suppliers",
                desc: "Every vendor is checked, rated & reviewed by buyers.",
              ),
              _BenefitCard(
                icon: Icons.handshake_outlined,
                color: AppColors.primary,
                title: "Direct Negotiation",
                desc: "Negotiate prices & terms directly with vendors.",
              ),
              _BenefitCard(
                icon: Icons.location_on_outlined,
                color: AppColors.primary,
                title: "Location-Based",
                desc: "Find suppliers near your construction site.",
              ),
              _BenefitCard(
                icon: Icons.receipt_long_outlined,
                color: AppColors.primary,
                title: "Transparent Pricing",
                desc: "See all costs upfront. No hidden charges.",
              ),
              _BenefitCard(
                icon: Icons.local_shipping_outlined,
                color: AppColors.primary,
                title: "Track Delivery",
                desc: "Real-time tracking from warehouse to site.",
              ),
              _BenefitCard(
                icon: Icons.support_agent_outlined,
                color: AppColors.primary,
                title: "Customer Support",
                desc: "24/7 assistance for your orders & concerns.",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── VENDOR BENEFITS SECTION ──────────────────────────────────────────────────
class _VendorBenefitsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: const Color(0xFFF8FAFF),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 72,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              "🚚 For Vendors",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "List, Manage & Grow",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Mini ERP platform to manage inventory, orders & revenue.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: isMobile ? 4.0 : 1.6,
            children: const [
              _BenefitCard(
                icon: Icons.storefront_outlined,
                color: Color(0xFF15803D),
                title: "Digital Storefront",
                desc: "List products with stock levels & real-time pricing.",
              ),
              _BenefitCard(
                icon: Icons.inventory_2_outlined,
                color: Color(0xFF15803D),
                title: "Inventory Management",
                desc:
                    "Track stock, auto-reorder alerts, multi-warehouse setup.",
              ),
              _BenefitCard(
                icon: Icons.analytics_outlined,
                color: Color(0xFF15803D),
                title: "Sales Analytics",
                desc:
                    "Revenue insights, customer trends & performance metrics.",
              ),
              _BenefitCard(
                icon: Icons.assignment_outlined,
                color: Color(0xFF15803D),
                title: "Order Management",
                desc: "Accept, process & fulfill orders from one dashboard.",
              ),
              _BenefitCard(
                icon: Icons.local_shipping_outlined,
                color: Color(0xFF15803D),
                title: "Delivery Integration",
                desc: "Manage deliveries & customer location tracking.",
              ),
              _BenefitCard(
                icon: Icons.trending_up_outlined,
                color: Color(0xFF15803D),
                title: "Grow Your Business",
                desc: "Reach verified buyers, build reputation & scale sales.",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _BenefitCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
  @override
  State<_BenefitCard> createState() => _BenefitCardState();
}

class _BenefitCardState extends State<_BenefitCard> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _hov ? widget.color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hov ? widget.color.withOpacity(0.4) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: _hov
                ? widget.color.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: _hov ? 20 : 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.desc,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── HOW IT WORKS ─────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF4FF), Color(0xFFF0FDF4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 72,
      ),
      child: Column(
        children: [
          const Text(
            "How It Works",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Three steps to connect buyers & suppliers",
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 52),
          isMobile
              ? Column(children: _steps())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _steps().map((s) => Expanded(child: s)).toList(),
                ),
        ],
      ),
    );
  }

  List<Widget> _steps() => [
    _Step(
      num: "01",
      icon: Icons.store_outlined,
      color: AppColors.primary,
      title: "Suppliers List",
      desc: "Vendors create profiles & list cement, sand, steel & aggregates.",
    ),
    _Step(
      num: "02",
      icon: Icons.search_rounded,
      color: const Color(0xFF0e6ab5),
      title: "Buyers Browse",
      desc: "Customers search materials, check prices, ratings & availability.",
    ),
    _Step(
      num: "03",
      icon: Icons.local_shipping_rounded,
      color: const Color(0xFF15803D),
      title: "Order & Deliver",
      desc: "Orders confirmed & delivered on time. Track in real-time.",
    ),
  ];
}

class _Step extends StatelessWidget {
  final String num, title, desc;
  final IconData icon;
  final Color color;
  const _Step({
    required this.num,
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              num,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: color.withOpacity(0.2),
                height: 1,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.bodyText,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

// ─── FEATURES SECTION ────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 72,
      ),
      child: Column(
        children: [
          const Text(
            "Why Sand Here?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: isMobile ? 4.0 : 1.5,
            children: const [
              _FeatCard(
                icon: Icons.verified_outlined,
                color: AppColors.primary,
                title: "Verified Network",
                desc: "All buyers & sellers are verified for trust & safety.",
              ),
              _FeatCard(
                icon: Icons.bolt_outlined,
                color: Color(0xFF15803D),
                title: "Fast Delivery",
                desc: "Same-day or scheduled delivery to match needs.",
              ),
              _FeatCard(
                icon: Icons.price_check_outlined,
                color: AppColors.primary,
                title: "Fair Pricing",
                desc: "Transparent pricing with no hidden charges.",
              ),
              _FeatCard(
                icon: Icons.inventory_2_outlined,
                color: Color(0xFF15803D),
                title: "All Materials",
                desc: "Cement, sand, steel, gravel & more in one place.",
              ),
              _FeatCard(
                icon: Icons.support_agent_outlined,
                color: AppColors.primary,
                title: "24/7 Support",
                desc: "Round-the-clock support for buyers & vendors.",
              ),
              _FeatCard(
                icon: Icons.shield_outlined,
                color: Color(0xFF15803D),
                title: "Secure Transactions",
                desc: "Safe payment & dispute resolution.",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _FeatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
  @override
  State<_FeatCard> createState() => _FeatCardState();
}

class _FeatCardState extends State<_FeatCard> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _hov ? widget.color.withOpacity(0.05) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hov ? widget.color.withOpacity(0.4) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: _hov
                ? widget.color.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: _hov ? 20 : 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.desc,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── CTA SECTION ──────────────────────────────────────────────────────────────
class _CTASection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CTASection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 60,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 28 : 64,
        vertical: 56,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF1565a0), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Ready to Join?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 26 : 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Join thousands of buyers and vendors already building with Sand Here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _WhiteBtn(label: "Order as Customer", onTap: onGetStarted),
              _OutlineWhiteBtn(label: "Supply as Vendor", onTap: onGetStarted),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── FOOTER ───────────────────────────────────────────��───────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: AppColors.titleText,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 36,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _content(),
            )
          : Row(children: _content()),
    );
  }

  List<Widget> _content() => [
    const AppLogo(size: 30),
    const SizedBox(width: 10, height: 10),
    const Text(
      "Sand Here",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    ),
    const Spacer(),
    Text(
      "© 2025 Sand Here. All rights reserved.",
      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
    ),
  ];
}

// ─── ROLE MODAL ───────────────────────────────────────────────────────────────
class _RoleModal extends StatelessWidget {
  final VoidCallback onClose;
  final Function(String) onSelect;
  const _RoleModal({required this.onClose, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppLogo(size: 32),
                          const SizedBox(width: 10),
                          const Text(
                            "Sand Here",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.titleText,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.subtleText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 20),
                  const Text(
                    "Who are you?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.titleText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Select your role to continue.",
                    style: TextStyle(fontSize: 13, color: AppColors.bodyText),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _ModalCard(
                          icon: Icons.shopping_bag_rounded,
                          label: "Customer",
                          desc: "Buy materials for your project",
                          color: AppColors.primary,
                          muted: AppColors.primaryMuted,
                          onTap: () => onSelect('customer'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ModalCard(
                          icon: Icons.local_shipping_rounded,
                          label: "Vendor",
                          desc: "Supply & deliver materials",
                          color: const Color(0xFF15803D),
                          muted: const Color(0xFFF0FDF4),
                          onTap: () => onSelect('vendor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalCard extends StatefulWidget {
  final IconData icon;
  final String label, desc;
  final Color color, muted;
  final VoidCallback onTap;
  const _ModalCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.muted,
    required this.onTap,
  });
  @override
  State<_ModalCard> createState() => _ModalCardState();
}

class _ModalCardState extends State<_ModalCard> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _hov ? widget.muted : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hov ? widget.color : AppColors.border,
            width: _hov ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
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

// ─── SHARED BUTTONS ───────────────────────────────────────────────────────────
class _WhiteBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  const _WhiteBtn({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });
  @override
  State<_WhiteBtn> createState() => _WhiteBtnState();
}

class _WhiteBtnState extends State<_WhiteBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: _hov ? const Color(0xFFF0F4FF) : Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _OutlineWhiteBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  const _OutlineWhiteBtn({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });
  @override
  State<_OutlineWhiteBtn> createState() => _OutlineWhiteBtnState();
}

class _OutlineWhiteBtnState extends State<_OutlineWhiteBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: _hov ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

class _GradientBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool small;
  const _GradientBtn({
    required this.label,
    required this.onTap,
    this.small = false,
  });
  @override
  State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: widget.small ? 14 : 24,
          vertical: widget.small ? 9 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hov
                ? [const Color(0xFF1565C0), const Color(0xFF0d5c38)]
                : [AppColors.primary, const Color(0xFF15803D)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _hov
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.small ? 12 : 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
