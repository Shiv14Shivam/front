import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';
import '../widgets/logo.dart';

class VendorHomePage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  const VendorHomePage({super.key, required this.onSelectView});

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // ── Stats from API ─────────────────────────────────────────────────────────
  bool _loading = true;

  // Order stats — computed from getVendorOrders()
  int _totalOrders = 0; // all order items
  int _pendingOrders = 0; // status == 'pending'
  int _acceptedOrders = 0; // status == 'accepted' (replaces "Dispatched")
  double _revenue =
      0; // sum(subtotal + delivery_charge) where payment_status == 'paid'

  // Inventory stats — from getVendorInventory()
  int _lowCount = 0;
  int _outCount = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Load both orders + inventory in parallel ───────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // Fire both requests simultaneously
    final results = await Future.wait([
      _api.getVendorOrders(),
      _api.getVendorInventory(),
    ]);

    if (!mounted) return;

    // ── Parse order stats ──────────────────────────────────────────────────
    final ordersRes = results[0];
    if (ordersRes['success'] == true) {
      // getVendorOrders returns {"data": [...]} where each item is an order-item wrapper
      final rawList = ordersRes['data'] as List? ?? [];

      int total = rawList.length;
      int pending = 0;
      int accepted = 0;
      double revenue = 0.0;

      for (final item in rawList) {
        // Each element: {"order_item": {...}, "order_id": ..., ...}
        // The actual order item data is nested under "order_item"
        final orderItem = (item['order_item'] as Map<String, dynamic>?) ?? {};

        final status = orderItem['status'] as String? ?? '';
        final paymentStatus =
            orderItem['payment_status'] as String? ?? 'unpaid';
        final subtotal = _toDouble(orderItem['subtotal']);
        // delivery_charge is on the order item (from OrderItem model)
        final deliveryCharge = _toDouble(orderItem['delivery_charge']);

        if (status == 'pending') pending++;
        if (status == 'accepted') accepted++;

        // Revenue: only count fully paid order items
        if (paymentStatus == 'paid') {
          revenue += subtotal + deliveryCharge;
        }
      }

      setState(() {
        _totalOrders = total;
        _pendingOrders = pending;
        _acceptedOrders = accepted;
        _revenue = revenue;
      });
    }

    // ── Parse inventory stats ──────────────────────────────────────────────
    final invRes = results[1];
    if (invRes['success'] == true) {
      final raw = (invRes['data'] as List? ?? []);
      final summary = (invRes['stock_summary'] as Map?) ?? {};

      final low =
          (summary['low_stock'] as int?) ??
          raw.where((e) {
            final s =
                ((e['inventory_summary'] as Map?)?['available_stock_unit'] ??
                        e['available_stock_unit'] ??
                        0)
                    as int;
            return s > 0 && s <= 10;
          }).length;

      final out =
          (summary['out_of_stock'] as int?) ??
          raw.where((e) {
            final s =
                ((e['inventory_summary'] as Map?)?['available_stock_unit'] ??
                        e['available_stock_unit'] ??
                        0)
                    as int;
            return s <= 0;
          }).length;

      setState(() {
        _lowCount = low;
        _outCount = out;
      });
    }

    setState(() => _loading = false);
    _fadeCtrl.forward();
  }

  // Safe double parser
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // Format revenue for display
  String _formatRevenue(double amount) {
    if (amount >= 10000000)
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && !Responsive.isMobile(context);

    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (!isDesktop) _buildMobileHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                color: AppColors.vendor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 20,
                    isDesktop ? 28 : 20,
                    isDesktop ? 28 : 20,
                    100,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: _loading
                          ? _loadingState()
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isDesktop) ...[
                                    _desktopGreeting(),
                                    const SizedBox(height: 28),
                                  ],
                                  _statsGrid(isDesktop: isDesktop),
                                  const SizedBox(height: 20),
                                  _stockAlert(),
                                  const SizedBox(height: 28),
                                  _sectionLabel("Quick Actions"),
                                  const SizedBox(height: 14),
                                  _quickActions(isDesktop: isDesktop),
                                  const SizedBox(height: 24),
                                  _addProductBanner(),
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
      ),
    );
  }

  // ── Loading shimmer-style placeholder ─────────────────────────────────────
  Widget _loadingState() => Column(
    children: [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.value<int>(
            context,
            mobile: 2,
            tablet: 2,
            desktop: 4,
          ),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: MediaQuery.of(context).size.width > 700 ? 1.7 : 1.4,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ],
  );

  // ── Desktop greeting ───────────────────────────────────────────────────────
  Widget _desktopGreeting() => Row(
    children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vendor Dashboard",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Here's what's happening with your store today.",
            style: TextStyle(fontSize: 14, color: AppColors.bodyText),
          ),
        ],
      ),
      const Spacer(),
      GestureDetector(
        onTap: () => widget.onSelectView(ViewType.listNewProduct),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.vendorGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.vendor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                "List Product",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  // ── Mobile header ──────────────────────────────────────────────────────────
  Widget _buildMobileHeader() => Container(
    decoration: const BoxDecoration(gradient: AppColors.vendorGradient),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Row(
          children: [
            const AppLogo(size: 36),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sand Here",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  "Vendor Dashboard",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onSelectView(ViewType.notifications),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Stats grid — REAL DATA ─────────────────────────────────────────────────
  Widget _statsGrid({required bool isDesktop}) {
    final stats = [
      _StatData(
        value: '$_totalOrders',
        label: "Total Orders",
        icon: Icons.receipt_long_rounded,
        color: AppColors.primary,
        muted: AppColors.primaryMuted,
        onTap: () => widget.onSelectView(ViewType.vendorRequestedOrder),
      ),
      _StatData(
        value: '$_pendingOrders',
        label: "Pending",
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        muted: AppColors.sandLight,
        onTap: () => widget.onSelectView(ViewType.vendorRequestedOrder),
      ),
      _StatData(
        // "Accepted" replaces "Dispatched" — no dispatch logic in backend yet
        value: '$_acceptedOrders',
        label: "Accepted",
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.vendor,
        muted: AppColors.vendorMuted,
        onTap: () => widget.onSelectView(ViewType.vendorRequestedOrder),
      ),
      _StatData(
        // Revenue = sum of (subtotal + delivery_charge) for paid order items
        value: _formatRevenue(_revenue),
        label: "Revenue (Paid)",
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF7C3AED),
        muted: const Color(0xFFF3F0FF),
        onTap: null,
      ),
    ];

    final cols = Responsive.value<int>(
      context,
      mobile: 2,
      tablet: 2,
      desktop: 4,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isDesktop ? 1.7 : 1.4,
      ),
      itemBuilder: (_, i) => _statCard(stats[i]),
    );
  }

  Widget _statCard(_StatData s) => GestureDetector(
    onTap: s.onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: s.muted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(s.icon, color: s.color, size: 20),
          ),
          const Spacer(),
          Text(
            s.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.titleText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            s.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.bodyText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Stock alert ────────────────────────────────────────────────────────────
  Widget _stockAlert() {
    if (_lowCount == 0 && _outCount == 0) return const SizedBox.shrink();

    final isOos = _outCount > 0;
    final alertColor = isOos ? AppColors.error : AppColors.warning;
    final bgColor = alertColor.withOpacity(0.05);
    final borderColor = alertColor.withOpacity(0.2);

    final parts = <String>[];
    if (_outCount > 0) parts.add('$_outCount out of stock');
    if (_lowCount > 0) parts.add('$_lowCount low stock');

    return GestureDetector(
      onTap: () => widget.onSelectView(ViewType.vendorInventory),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: alertColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOos ? 'Stock Alert' : 'Low Stock Warning',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: alertColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${parts.join(' · ')} — tap to restock',
                    style: TextStyle(
                      fontSize: 12,
                      color: alertColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "View →",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: alertColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppColors.titleText,
      letterSpacing: -0.2,
    ),
  );

  // ── Quick actions ──────────────────────────────────────────────────────────
  Widget _quickActions({required bool isDesktop}) {
    final actions = [
      _ActionData(
        icon: Icons.pending_actions_outlined,
        label: "Orders",
        desc: "View & manage incoming orders",
        color: AppColors.primary,
        muted: AppColors.primaryMuted,
        onTap: () => widget.onSelectView(ViewType.vendorRequestedOrder),
      ),
      _ActionData(
        icon: Icons.inventory_2_outlined,
        label: "Inventory",
        desc: "Stock levels & restock alerts",
        color: AppColors.vendor,
        muted: AppColors.vendorMuted,
        onTap: () => widget.onSelectView(ViewType.vendorInventory),
      ),
      _ActionData(
        icon: Icons.notifications_outlined,
        label: "Notifications",
        desc: "Updates & delivery alerts",
        color: AppColors.warning,
        muted: AppColors.sandLight,
        onTap: () => widget.onSelectView(ViewType.notifications),
      ),
      _ActionData(
        icon: Icons.person_outline_rounded,
        label: "Profile",
        desc: "Business info & addresses",
        color: const Color(0xFF7C3AED),
        muted: const Color(0xFFF3F0FF),
        onTap: () => widget.onSelectView(ViewType.vendorProfile),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isDesktop ? 1.8 : 1.5,
      ),
      itemBuilder: (_, i) => _actionCard(actions[i]),
    );
  }

  Widget _actionCard(_ActionData a) => GestureDetector(
    onTap: a.onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: a.muted,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.subtleText,
                  size: 16,
                ),
              ],
            ),
            const Spacer(),
            Text(
              a.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              a.desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.subtleText),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Add product banner ─────────────────────────────────────────────────────
  Widget _addProductBanner() => GestureDetector(
    onTap: () => widget.onSelectView(ViewType.listNewProduct),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.vendorGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.vendor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _DotPainter()),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        "🏪  Expand your store",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "List a New Product",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Add cement, sand or steel to your marketplace listing.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
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
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Data models ────────────────────────────────────────────────────────────────
class _StatData {
  final String value, label;
  final IconData icon;
  final Color color, muted;
  final VoidCallback? onTap;
  const _StatData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.muted,
    this.onTap,
  });
}

class _ActionData {
  final IconData icon;
  final String label, desc;
  final Color color, muted;
  final VoidCallback onTap;
  const _ActionData({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.muted,
    required this.onTap,
  });
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.1);
    for (double x = 0; x < size.width; x += 24)
      for (double y = 0; y < size.height; y += 24)
        canvas.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
