import 'package:flutter/material.dart';
import 'package:front/theme/app_colors.dart';
import '../view_type.dart';
import '../widgets/logo.dart';

class VendorHomePage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  const VendorHomePage({super.key, required this.onSelectView});

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _statsFade;
  late Animation<Offset> _statsSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _pulse;

  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();

    // Main staggered entry
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Subtle pulse for alert card
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Shimmer on revenue card
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Staggered animations
    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

    _statsFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    _statsSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.2, 0.65, curve: Curves.easeOut),
          ),
        );

    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
          ),
        );

    _pulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          // Animated header
          FadeTransition(
            opacity: _headerFade,
            child: SlideTransition(
              position: _headerSlide,
              child: _buildHeader(),
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats grid — staggered
                  FadeTransition(
                    opacity: _statsFade,
                    child: SlideTransition(
                      position: _statsSlide,
                      child: _buildStatsGrid(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Alert + actions — slightly later
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLowStockAlert(),
                          const SizedBox(height: 24),
                          _sectionLabel("Quick Actions"),
                          const SizedBox(height: 12),
                          _buildActionTile(
                            icon: Icons.pending_actions_outlined,
                            title: "Requested Orders",
                            subtitle: "23 orders waiting for approval",
                            count: "23",
                            color: AppColors.warning,
                            onTap: () => widget.onSelectView(
                              ViewType.vendorRequestedOrder,
                            ),
                          ),
                          _buildActionTile(
                            icon: Icons.local_shipping_outlined,
                            title: "Dispatched Orders",
                            subtitle: "98 orders currently in transit",
                            count: "98",
                            color: AppColors.vendor,
                            onTap: () {},
                          ),
                          _buildActionTile(
                            icon: Icons.inventory_2_outlined,
                            title: "Inventory Management",
                            subtitle: "View and manage stock levels",
                            count: "8",
                            color: AppColors.primary,
                            onTap: () {},
                          ),
                          _buildActionTile(
                            icon: Icons.analytics_outlined,
                            title: "Analytics & Reports",
                            subtitle: "View sales and performance",
                            color: const Color(0xFF7C3AED),
                            onTap: () {},
                          ),
                          const SizedBox(height: 8),
                          _buildAddProductBanner(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.vendorGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 24),
          child: Row(
            children: [
              // Logo + brand
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const AppLogo(size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Vendor Dashboard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      "SandHere Supplier",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.sand,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats Grid ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        "156",
        "Total Orders",
        Icons.inventory_2_outlined,
        AppColors.primary,
        AppColors.primaryMuted,
      ),
      _StatData(
        "23",
        "Pending",
        Icons.pending_actions_outlined,
        AppColors.warning,
        AppColors.sandLight,
      ),
      _StatData(
        "98",
        "Dispatched",
        Icons.local_shipping_outlined,
        AppColors.vendor,
        AppColors.vendorMuted,
      ),
      _StatData(
        "₹24.5L",
        "Revenue",
        Icons.trending_up_rounded,
        const Color(0xFF7C3AED),
        const Color(0xFFF3E8FF),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15, // ← gives cards enough height
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        // Each card staggers in individually
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + i * 100),
          curve: Curves.easeOut,
          builder: (context, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: child,
            ),
          ),
          child: _buildStatCard(stats[i]),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData data) {
    final isRevenue = data.label == "Revenue";

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: data.color.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: data.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data.icon, color: data.color, size: 18),
                  ),
                  if (isRevenue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vendorMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "↑ 12%",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.vendor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.titleText,
                  letterSpacing: isRevenue ? -0.5 : 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.bodyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Low Stock Alert ────────────────────────────────────────────────────────

  Widget _buildLowStockAlert() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) =>
          Transform.scale(scale: _pulse.value, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Low Stock Alert",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.titleText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "8 items need restocking soon",
                    style: TextStyle(fontSize: 12, color: AppColors.bodyText),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "View",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Tiles ───────────────────────────────────────────────────────────

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.06),
          highlightColor: color.withOpacity(0.03),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.subtleText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Add Product Banner ─────────────────────────────────────────────────────

  Widget _buildAddProductBanner() {
    return GestureDetector(
      onTap: () => widget.onSelectView(ViewType.listNewProduct),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.vendorGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.vendor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "List a New Product",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Expand your marketplace presence",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Add Product →",
                      style: TextStyle(
                        color: AppColors.vendor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_box_outlined,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
              _navItem(
                1,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = _selectedNav == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedNav = index);
          if (index == 1) widget.onSelectView(ViewType.vendorProfile);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.vendor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive ? AppColors.vendor : AppColors.subtleText,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppColors.vendor : AppColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.titleText,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Data model for stat cards ──────────────────────────────────────────────────

class _StatData {
  final String value, label;
  final IconData icon;
  final Color color, bgColor;
  const _StatData(this.value, this.label, this.icon, this.color, this.bgColor);
}
