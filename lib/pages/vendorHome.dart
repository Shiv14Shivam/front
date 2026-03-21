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

class _VendorHomePageState extends State<VendorHomePage> {
  final _api = ApiService();

  int _selectedNav = 0;

  // ── Real inventory stats ───────────────────────────────────────────────────
  bool _statsLoading = true;
  int _lowCount = 0;
  int _outCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInventoryStats();
  }

  Future<void> _loadInventoryStats() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);

    final res = await _api.getVendorInventory(); // fetch all listings
    if (!mounted) return;

    if (res['success'] == true) {
      final raw = (res['data'] as List? ?? []);
      final summary = (res['stock_summary'] as Map?) ?? {};

      // Prefer server-side summary if available, otherwise compute locally
      final low =
          (summary['low_stock'] as int?) ??
          raw.where((e) {
            final stock =
                ((e['inventory_summary'] as Map?)?['available_stock_bags'] ??
                        e['available_stock_bags'] ??
                        0)
                    as int;
            return stock > 0 && stock <= 10;
          }).length;

      final out =
          (summary['out_of_stock'] as int?) ??
          raw.where((e) {
            final stock =
                ((e['inventory_summary'] as Map?)?['available_stock_bags'] ??
                        e['available_stock_bags'] ??
                        0)
                    as int;
            return stock <= 0;
          }).length;

      setState(() {
        _lowCount = low;
        _outCount = out;
        _statsLoading = false;
      });
    } else {
      setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb && !Responsive.isMobile(context);

    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
        body: Column(
          children: [
            if (!isDesktop) _buildHeader(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: RefreshIndicator(
                    onRefresh: _loadInventoryStats,
                    color: AppColors.vendor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsGrid(),
                          const SizedBox(height: 24),

                          // ✅ Real low stock alert — hidden when 0
                          _buildLowStockAlert(),

                          const SizedBox(height: 24),
                          _sectionTitle("Quick Actions"),
                          const SizedBox(height: 12),
                          _buildActionGrid(),
                          const SizedBox(height: 16),
                          _buildAddProductBanner(),
                        ],
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.vendorGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const AppLogo(size: 28),
              const SizedBox(width: 10),
              const Text(
                "Vendor Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => widget.onSelectView(ViewType.notifications),
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
      _Stat("156", "Orders", Icons.inventory, AppColors.primary),
      _Stat("23", "Pending", Icons.pending, AppColors.warning),
      _Stat("98", "Dispatched", Icons.local_shipping, AppColors.vendor),
      _Stat("₹24.5L", "Revenue", Icons.trending_up, Colors.purple),
    ];

    final columns = Responsive.value(context, mobile: 2, tablet: 2, desktop: 4);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: Responsive.value(
          context,
          mobile: 1.1,
          tablet: 1.2,
          desktop: 1.4,
        ),
      ),
      itemBuilder: (_, i) => _statCard(stats[i]),
    );
  }

  Widget _statCard(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, color: s.color),
          const Spacer(),
          Text(
            s.value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(s.label, style: const TextStyle(color: AppColors.bodyText)),
        ],
      ),
    );
  }

  // ── Low Stock Alert — REAL data ────────────────────────────────────────────
  Widget _buildLowStockAlert() {
    // Still loading — show shimmer placeholder
    if (_statsLoading) {
      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    // Nothing to alert about — hide entirely
    if (_lowCount == 0 && _outCount == 0) return const SizedBox.shrink();

    // Determine severity: out-of-stock is more urgent than low stock
    final isOos = _outCount > 0;
    final alertColor = isOos ? AppColors.error : AppColors.warning;
    final bgColor = isOos
        ? AppColors.error.withOpacity(0.06)
        : AppColors.warning.withOpacity(0.06);
    final borderColor = isOos
        ? AppColors.error.withOpacity(0.25)
        : AppColors.warning.withOpacity(0.25);

    // Build message
    final parts = <String>[];
    if (_outCount > 0) {
      parts.add('$_outCount out of stock');
    }
    if (_lowCount > 0) {
      parts.add('$_lowCount low stock');
    }
    final message = '${parts.join(' · ')} — tap to restock';

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
              padding: const EdgeInsets.all(8),
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
            const SizedBox(width: 12),
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
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: alertColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'View →',
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

  // ── Action Grid ────────────────────────────────────────────────────────────
  Widget _buildActionGrid() {
    final actions = [
      _Action("Orders", Icons.list, () {
        widget.onSelectView(ViewType.vendorRequestedOrder);
      }),
      _Action("Inventory", Icons.inventory, () {
        widget.onSelectView(ViewType.vendorInventory);
      }),
      _Action("Analytics", Icons.bar_chart, () {}),
      _Action("Profile", Icons.person, () {
        widget.onSelectView(ViewType.vendorProfile);
      }),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3.5,
            children: actions.map((a) => _actionTile(a)).toList(),
          );
        }
        return Column(children: actions.map((a) => _actionTile(a)).toList());
      },
    );
  }

  Widget _actionTile(_Action a) {
    return Card(
      child: ListTile(
        leading: Icon(a.icon, color: AppColors.primary),
        title: Text(a.title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: a.onTap,
      ),
    );
  }

  // ── Banner ─────────────────────────────────────────────────────────────────
  Widget _buildAddProductBanner() {
    return GestureDetector(
      onTap: () => widget.onSelectView(ViewType.listNewProduct),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.vendorGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                "Add New Product",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Icon(Icons.add, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedNav,
      onTap: (i) {
        setState(() => _selectedNav = i);
        if (i == 1) widget.onSelectView(ViewType.vendorProfile);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
}

// ── Models ─────────────────────────────────────────────────────────────────
class _Stat {
  final String value, label;
  final IconData icon;
  final Color color;
  _Stat(this.value, this.label, this.icon, this.color);
}

class _Action {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _Action(this.title, this.icon, this.onTap);
}
