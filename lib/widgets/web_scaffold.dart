import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:front/widgets/logo.dart';
import '../utils/responsive.dart';
import '../view_type.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class WebScaffold extends StatefulWidget {
  final Widget body;
  final bool isVendor;
  final int selectedIndex;
  final Function(ViewType) onSelectView;

  const WebScaffold({
    super.key,
    required this.body,
    required this.onSelectView,
    this.isVendor = false,
    this.selectedIndex = 0,
  });

  @override
  State<WebScaffold> createState() => _WebScaffoldState();
}

class _WebScaffoldState extends State<WebScaffold>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  int _unreadCount = 0;

  // Pulse animation for the bell when unread > 0
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fetch unread count on mount, then poll every 30s
    _fetchUnreadCount();
    _startPolling();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    final count = await _api.getUnreadNotificationCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (!mounted) return false;
      await _fetchUnreadCount();
      return mounted;
    });
  }

  // Called from notifications page after marking all read
  void clearUnreadCount() {
    if (mounted) setState(() => _unreadCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    // On mobile — render body as-is
    if (!kIsWeb || Responsive.isMobile(context)) {
      return widget.body;
    }

    // On desktop web — wrap with sidebar + top bar
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                if (Responsive.isDesktop(context)) _buildTopBar(context),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: widget.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context) {
    final items = widget.isVendor ? _vendorNavItems : _customerNavItems;

    return Container(
      width: Responsive.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            decoration: BoxDecoration(
              gradient: widget.isVendor
                  ? AppColors.vendorGradient
                  : const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
            ),
            child: const Row(
              children: [
                AppLogo(size: 38),
                SizedBox(width: 10),
                Text(
                  "Sand Here",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Nav items
          ...items.map(
            (item) => _sidebarItem(
              context,
              icon: item.icon,
              label: item.label,
              viewType: item.viewType,
              // Show badge on the Notifications item
              badge: item.viewType == ViewType.notifications && _unreadCount > 0
                  ? _unreadCount
                  : 0,
            ),
          ),

          const Spacer(),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: _sidebarItem(
              context,
              icon: Icons.logout_rounded,
              label: "Sign Out",
              viewType: ViewType.login,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ViewType viewType,
    bool isDestructive = false,
    int badge = 0,
  }) {
    final isSelected = _isCurrentView(viewType);
    final color = isDestructive
        ? AppColors.error
        : isSelected
        ? (widget.isVendor ? AppColors.vendor : AppColors.primary)
        : AppColors.bodyText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? (widget.isVendor ? AppColors.vendorMuted : AppColors.primaryMuted)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Reset unread count when opening notifications
            if (viewType == ViewType.notifications) {
              setState(() => _unreadCount = 0);
            }
            widget.onSelectView(viewType);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Bell icon glows when unread > 0
                viewType == ViewType.notifications
                    ? _buildBellIcon(color, badge)
                    : Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                // Badge count pill
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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

  // Pulsing bell icon — only animates when there are unread notifications
  Widget _buildBellIcon(Color color, int badge) {
    if (badge == 0) {
      return Icon(Icons.notifications_outlined, size: 20, color: color);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Glow ring behind bell
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withOpacity(
                    0.15 * _pulseAnimation.value,
                  ),
                ),
              ),
            ),
            Icon(Icons.notifications_rounded, size: 20, color: AppColors.error),
          ],
        );
      },
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final titles = widget.isVendor
        ? [
            'Dashboard',
            'Orders',
            'Inventory',
            'List Product',
            'Notifications',
            'Profile',
          ]
        : ['Marketplace', 'Cart', 'Notifications', 'Profile'];

    final title =
        (widget.selectedIndex >= 0 && widget.selectedIndex < titles.length)
        ? titles[widget.selectedIndex]
        : 'Sand Here';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.titleText,
            ),
          ),
          const Spacer(),

          // ── Bell icon in top bar ────────────────────────────────────────
          GestureDetector(
            onTap: () {
              setState(() => _unreadCount = 0);
              widget.onSelectView(ViewType.notifications);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _unreadCount > 0
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, __) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Pulsing glow
                            Positioned(
                              top: -4,
                              left: -4,
                              right: -4,
                              bottom: -4,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error.withOpacity(
                                    0.12 * _pulseAnimation.value,
                                  ),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.notifications_rounded,
                              color: AppColors.error,
                              size: 24,
                            ),
                            // Count badge
                            Positioned(
                              top: -5,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.bodyText,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => widget.onSelectView(
              widget.isVendor
                  ? ViewType.vendorProfile
                  : ViewType.cutomerProfile,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: widget.isVendor
                  ? AppColors.vendorMuted
                  : AppColors.primaryMuted,
              child: Icon(
                Icons.person,
                size: 18,
                color: widget.isVendor ? AppColors.vendor : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentView(ViewType viewType) {
    final vendorItems = [
      ViewType.vendorHome,
      ViewType.vendorRequestedOrder,
      ViewType.vendorInventory,
      ViewType.listNewProduct,
      ViewType.notifications,
      ViewType.vendorProfile,
    ];
    final customerItems = [
      ViewType.customerHome,
      ViewType.cart,
      ViewType.notifications,
      ViewType.cutomerProfile,
    ];

    final items = widget.isVendor ? vendorItems : customerItems;
    final currentIndex = items.indexOf(viewType);
    return currentIndex == widget.selectedIndex;
  }

  List<_NavItem> get _vendorNavItems => [
    _NavItem(Icons.home_rounded, "Dashboard", ViewType.vendorHome),
    _NavItem(
      Icons.pending_actions_outlined,
      "Orders",
      ViewType.vendorRequestedOrder,
    ),
    _NavItem(Icons.inventory_2_outlined, "Inventory", ViewType.vendorInventory),
    _NavItem(Icons.add_box_outlined, "List Product", ViewType.listNewProduct),
    _NavItem(
      Icons.notifications_outlined,
      "Notifications",
      ViewType.notifications,
    ),
    _NavItem(Icons.person_outline, "Profile", ViewType.vendorProfile),
  ];

  List<_NavItem> get _customerNavItems => [
    _NavItem(Icons.store_outlined, "Marketplace", ViewType.customerHome),
    _NavItem(Icons.shopping_cart_outlined, "Cart", ViewType.cart),
    _NavItem(
      Icons.notifications_outlined,
      "Notifications",
      ViewType.notifications,
    ),
    _NavItem(Icons.person_outline, "Profile", ViewType.cutomerProfile),
  ];
}

class _NavItem {
  final IconData icon;
  final String label;
  final ViewType viewType;
  const _NavItem(this.icon, this.label, this.viewType);
}
