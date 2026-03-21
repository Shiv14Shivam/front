import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front/services/api_service.dart';
import 'package:front/theme/app_colors.dart';
import 'package:front/utils/responsive.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart'; // ✅ added

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _Listing {
  final int id;
  final String productName;
  final String brandName;
  final String categoryName;
  final String? imageUrl;
  final double pricePerBag;
  final double deliveryChargePerTon;
  final int availableStock;
  final int totalAccepted;
  final int pendingBags;
  final String status;
  final String? rejectionReason;

  _Listing({
    required this.id,
    required this.productName,
    required this.brandName,
    required this.categoryName,
    this.imageUrl,
    required this.pricePerBag,
    required this.deliveryChargePerTon,
    required this.availableStock,
    required this.totalAccepted,
    required this.pendingBags,
    required this.status,
    this.rejectionReason,
  });

  factory _Listing.fromJson(Map<String, dynamic> j) {
    final product = (j['product'] as Map?) ?? {};
    final brand = (j['brand'] as Map?) ?? {};
    final category = (j['category'] as Map?) ?? {};
    final inv = (j['inventory_summary'] as Map?) ?? {};
    return _Listing(
      id: j['id'] as int,
      productName: (product['name'] ?? '-') as String,
      brandName: (brand['name'] ?? '-') as String,
      categoryName: (category['name'] ?? '-') as String,
      imageUrl: product['image_url'] as String?,
      pricePerBag: double.tryParse('${j['price_per_bag']}') ?? 0,
      deliveryChargePerTon:
          double.tryParse('${j['delivery_charge_per_ton']}') ?? 0,
      availableStock:
          (inv['available_stock_bags'] ?? j['available_stock_bags'] ?? 0)
              as int,
      totalAccepted: (inv['total_accepted_bags'] ?? 0) as int,
      pendingBags: (inv['pending_request_bags'] ?? 0) as int,
      status: (j['status'] ?? 'inactive') as String,
      rejectionReason: j['rejection_reason'] as String?,
    );
  }

  bool get isOos => availableStock <= 0;
  bool get isLow => availableStock > 0 && availableStock <= 10;

  _Listing withStock(int s) => _Listing(
    id: id,
    productName: productName,
    brandName: brandName,
    categoryName: categoryName,
    imageUrl: imageUrl,
    pricePerBag: pricePerBag,
    deliveryChargePerTon: deliveryChargePerTon,
    availableStock: s,
    totalAccepted: totalAccepted,
    pendingBags: pendingBags,
    status: (s > 0 && status == 'inactive') ? 'active' : status,
    rejectionReason: rejectionReason,
  );

  _Listing withPrices(double ppb, double dcpt) => _Listing(
    id: id,
    productName: productName,
    brandName: brandName,
    categoryName: categoryName,
    imageUrl: imageUrl,
    pricePerBag: ppb,
    deliveryChargePerTon: dcpt,
    availableStock: availableStock,
    totalAccepted: totalAccepted,
    pendingBags: pendingBags,
    status: status,
    rejectionReason: rejectionReason,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class VendorInventoryPage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  const VendorInventoryPage({super.key, required this.onSelectView});

  @override
  State<VendorInventoryPage> createState() => _VendorInventoryPageState();
}

class _VendorInventoryPageState extends State<VendorInventoryPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _pulse;

  final _api = ApiService();

  List<_Listing> _listings = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  final _searchCtrl = TextEditingController();
  int _tab = 0;

  static const _tabs = [
    'All',
    'Active',
    'Low Stock',
    'Out of Stock',
    'Pending',
    'Inactive',
  ];

  int _total = 0, _lowCount = 0, _outCount = 0;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _headerFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );
    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _load();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _apiStatus => switch (_tab) {
    1 => 'active',
    4 => 'pending',
    5 => 'inactive',
    _ => null,
  };

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _api.getVendorInventory(status: _apiStatus);
    if (!mounted) return;
    if (res['success'] == true) {
      final raw = (res['data'] as List? ?? []);
      final s = (res['stock_summary'] as Map?) ?? {};
      setState(() {
        _listings = raw
            .map((e) => _Listing.fromJson(e as Map<String, dynamic>))
            .toList();
        _total = (s['total_listings'] ?? _listings.length) as int;
        _lowCount = (s['low_stock'] ?? 0) as int;
        _outCount = (s['out_of_stock'] ?? 0) as int;
        _loading = false;
      });
      _entryCtrl.forward(from: 0);
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Failed';
        _loading = false;
      });
    }
  }

  List<_Listing> get _filtered {
    var base = _listings;
    if (_tab == 2) base = base.where((l) => l.isLow).toList();
    if (_tab == 3) base = base.where((l) => l.isOos).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      base = base
          .where(
            (l) =>
                l.productName.toLowerCase().contains(q) ||
                l.brandName.toLowerCase().contains(q) ||
                l.categoryName.toLowerCase().contains(q),
          )
          .toList();
    }
    return base;
  }

  Future<void> _restock(_Listing listing, int bags) async {
    final optimistic = listing.withStock(listing.availableStock + bags);
    setState(() {
      final i = _listings.indexWhere((l) => l.id == listing.id);
      if (i != -1) _listings[i] = optimistic;
    });
    final res = await _api.restockListing(listing.id, bags);
    if (!mounted) return;
    if (res['success'] == true) {
      final confirmed =
          (res['new_stock_bags'] as int?) ?? optimistic.availableStock;
      setState(() {
        final i = _listings.indexWhere((l) => l.id == listing.id);
        if (i != -1) _listings[i] = _listings[i].withStock(confirmed);
      });
      _snack('✅ Restocked ${listing.productName} +$bags bags', true);
    } else {
      setState(() {
        final i = _listings.indexWhere((l) => l.id == listing.id);
        if (i != -1) _listings[i] = listing;
      });
      _snack(res['message'] as String? ?? 'Restock failed', false);
    }
  }

  Future<void> _updatePrices(_Listing listing, double ppb, double dcpt) async {
    final optimistic = listing.withPrices(ppb, dcpt);
    setState(() {
      final i = _listings.indexWhere((l) => l.id == listing.id);
      if (i != -1) _listings[i] = optimistic;
    });
    final res = await _api.updateListingPrices(
      listing.id,
      pricePerBag: ppb,
      deliveryChargePerTon: dcpt,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      final confirmedPpb = double.tryParse('${res['price_per_bag']}') ?? ppb;
      final confirmedDcpt =
          double.tryParse('${res['delivery_charge_per_ton']}') ?? dcpt;
      setState(() {
        final i = _listings.indexWhere((l) => l.id == listing.id);
        if (i != -1)
          _listings[i] = _listings[i].withPrices(confirmedPpb, confirmedDcpt);
      });
      _snack('✅ Prices updated for ${listing.productName}', true);
    } else {
      setState(() {
        final i = _listings.indexWhere((l) => l.id == listing.id);
        if (i != -1) _listings[i] = listing;
      });
      _snack(res['message'] as String? ?? 'Update failed', false);
    }
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: ok ? AppColors.vendor : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  // ✅ Only this method changed — WebScaffold wraps the original Scaffold

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 2,

      body: Scaffold(
        backgroundColor: AppColors.background,

        // ✅ hide bottom nav on desktop
        bottomNavigationBar: isDesktop ? null : _bottomNav(),

        body: Column(
          children: [
            // ✅ mobile header only
            if (!isDesktop)
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: _header(),
                ),
              ),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.vendor),
                    )
                  : _error != null
                  ? _errorView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: _bodyResponsive(),
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
  Widget _header() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.vendorGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onSelectView(ViewType.vendorHome),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'SandHere Supplier',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _chip('$_total', 'Total'),
                  const SizedBox(width: 8),
                  _chip('$_outCount', 'OOS', isAlert: _outCount > 0),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final active = _tab == i;
                  return GestureDetector(
                    onTap: () {
                      if (_tab == i) return;
                      setState(() {
                        _tab = i;
                        _search = '';
                        _searchCtrl.clear();
                      });
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: active
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.vendor
                              : Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String val, String label, {bool isAlert = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isAlert
            ? AppColors.error.withOpacity(0.6)
            : Colors.white.withOpacity(0.3),
      ),
    ),
    child: Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isAlert ? const Color(0xFFFFCDD2) : Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isAlert ? const Color(0xFFFFCDD2) : Colors.white70,
          ),
        ),
      ],
    ),
  );

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _bodyResponsive() {
    final items = _filtered;
    final isDesktop = Responsive.isDesktop(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Responsive.isDesktop(context))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Inventory",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _chip('$_total', 'Total'),
                    const SizedBox(width: 8),
                    _chip('$_outCount', 'OOS', isAlert: _outCount > 0),
                  ],
                ),
                const SizedBox(height: 16),

                // ✅ TABS ON DESKTOP
                Wrap(
                  spacing: 10,
                  children: List.generate(_tabs.length, (i) {
                    final active = _tab == i;
                    return GestureDetector(
                      onTap: () {
                        if (_tab == i) return;
                        setState(() {
                          _tab = i;
                          _search = '';
                          _searchCtrl.clear();
                        });
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.vendor : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.vendor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.vendor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
              ],
            ),
          _searchBar(),
          const SizedBox(height: 12),

          if (_lowCount > 0) ...[_lowStockAlert(), const SizedBox(height: 14)],

          Text(
            '${items.length} products',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            _empty()
          else if (isDesktop)
            _gridView(items)
          else
            _listView(items),

          const SizedBox(height: 20),
          const SizedBox(height: 20),

          if (!Responsive.isDesktop(context)) _addBanner(),
        ],
      ),
    );
  }

  Widget _listView(List<_Listing> items) {
    return Column(
      children: List.generate(
        items.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Card(
            listing: items[i],
            onRestock: (bags) => _restock(items[i], bags),
            onUpdatePrices: (ppb, dcpt) => _updatePrices(items[i], ppb, dcpt),
          ),
        ),
      ),
    );
  }

  Widget _gridView(List<_Listing> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.value(
          context,
          mobile: 1,
          tablet: 2,
          desktop: 3, // ✅ more columns
        ),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: Responsive.value(
          context,
          mobile: 1.3,
          tablet: 1.5,
          desktop: 1.9, // ✅ smaller cards
        ),
      ),
      itemBuilder: (_, i) => _Card(
        listing: items[i],
        onRestock: (bags) => _restock(items[i], bags),
        onUpdatePrices: (ppb, dcpt) => _updatePrices(items[i], ppb, dcpt),
      ),
    );
  }

  Widget _searchBar() => Container(
    height: 46,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _search = v),
      style: const TextStyle(fontSize: 14, color: AppColors.titleText),
      decoration: const InputDecoration(
        hintText: 'Search products, brands…',
        hintStyle: TextStyle(color: AppColors.subtleText, fontSize: 14),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppColors.subtleText,
          size: 20,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );

  Widget _lowStockAlert() => AnimatedBuilder(
    animation: _pulse,
    builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
    child: GestureDetector(
      onTap: () {
        setState(() => _tab = 2);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Low Stock Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.titleText,
                    ),
                  ),
                  Text(
                    '$_lowCount item${_lowCount == 1 ? '' : 's'} need restocking',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.bodyText,
                    ),
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
                'View',
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
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.vendorMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppColors.vendor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No listings found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a different filter',
            style: TextStyle(fontSize: 12, color: AppColors.bodyText),
          ),
        ],
      ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.subtleText,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.bodyText, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.vendorGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _addBanner() => GestureDetector(
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
                  'List a New Product',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expand your marketplace presence',
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
                    'Add Product →',
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

  // ── Bottom Nav (mobile only) ───────────────────────────────────────────────
  Widget _bottomNav() => Container(
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
            _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
            _navItem(
              1,
              Icons.person_rounded,
              Icons.person_outline_rounded,
              'Profile',
            ),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(int idx, IconData active, IconData inactive, String label) {
    final on = idx == 0;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (idx == 0) widget.onSelectView(ViewType.vendorHome);
          if (idx == 1) widget.onSelectView(ViewType.vendorProfile);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.vendor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? active : inactive,
                color: on ? AppColors.vendor : AppColors.subtleText,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  color: on ? AppColors.vendor : AppColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final _Listing listing;
  final void Function(int bags) onRestock;
  final void Function(double, double) onUpdatePrices;

  const _Card({
    required this.listing,
    required this.onRestock,
    required this.onUpdatePrices,
  });

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: l.isOos
              ? AppColors.error.withOpacity(0.25)
              : l.isLow
              ? AppColors.warning.withOpacity(0.25)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.vendorMuted,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: l.imageUrl != null
                      ? Image.network(
                          l.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.vendor,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.vendor,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.titleText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l.brandName} · ${l.categoryName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtleText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₹${l.pricePerBag.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            ' / bag',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                            ),
                          ),
                          if (l.deliveryChargePerTon > 0) ...[
                            const Text(
                              '  ·  ',
                              style: TextStyle(color: AppColors.subtleText),
                            ),
                            Text(
                              '₹${l.deliveryChargePerTon.toStringAsFixed(0)}/ton',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.subtleText,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showEditPriceSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(l.status),
              ],
            ),
          ),

          if (l.status == 'rejected' && l.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.rejectionReason!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (l.isOos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: AppColors.error.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.block_rounded, size: 13, color: AppColors.error),
                  SizedBox(width: 7),
                  Text(
                    'Out of stock — listing paused automatically',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Icon(
                    l.isLow
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 14,
                    color: l.isLow ? AppColors.warning : AppColors.vendor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.isLow ? 'Low Stock — ' : 'Stock: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: l.isLow ? AppColors.warning : AppColors.bodyText,
                    ),
                  ),
                  Text(
                    '${l.availableStock} bags',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: l.isLow ? AppColors.warning : AppColors.titleText,
                    ),
                  ),
                  const Spacer(),
                  if (l.totalAccepted > 0)
                    Text(
                      '${l.totalAccepted} accepted',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtleText,
                      ),
                    ),
                  if (l.pendingBags > 0) ...[
                    const Text(
                      '  ·  ',
                      style: TextStyle(color: AppColors.subtleText),
                    ),
                    Text(
                      '${l.pendingBags} pending',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtleText,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                      ),
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                        ),
                        splashColor: AppColors.vendor.withOpacity(0.06),
                        onTap: () => _showRestockSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                l.isOos
                                    ? Icons.add_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: l.isOos
                                    ? AppColors.error
                                    : AppColors.vendor,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l.isOos ? 'Add Stock' : 'Restock',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: l.isOos
                                      ? AppColors.error
                                      : AppColors.vendor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(18),
                      ),
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(18),
                        ),
                        splashColor: AppColors.primary.withOpacity(0.06),
                        onTap: () => _showEditPriceSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.currency_rupee_rounded,
                                color: AppColors.primary,
                                size: 17,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Edit Price',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  void _showRestockSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestockSheet(listing: listing, onConfirm: onRestock),
    );
  }

  void _showEditPriceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditPriceSheet(listing: listing, onConfirm: onUpdatePrices),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESTOCK SHEET — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _RestockSheet extends StatefulWidget {
  final _Listing listing;
  final void Function(int) onConfirm;
  const _RestockSheet({required this.listing, required this.onConfirm});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _ctrl = TextEditingController(text: '50');
  String? _err;

  void _validate(String v) {
    final n = int.tryParse(v);
    setState(() => _err = (n == null || n < 1) ? 'Enter a valid number' : null);
  }

  void _confirm() {
    final n = int.tryParse(_ctrl.text);
    if (n == null || n < 1) return;
    Navigator.pop(context);
    widget.onConfirm(n);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Restock',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.listing.productName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            Text(
              'Current: ${widget.listing.availableStock} bags',
              style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              onChanged: _validate,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
              decoration: InputDecoration(
                suffixText: 'bags',
                suffixStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.subtleText,
                  fontWeight: FontWeight.w600,
                ),
                errorText: _err,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.vendor,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [50, 100, 200, 500].map((p) {
                final last = p == 500;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _ctrl.text = '$p';
                      _validate('$p');
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.vendorMuted,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.vendor.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        '+$p',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.vendor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _err == null ? _confirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _err == null
                      ? AppColors.vendorGradient
                      : const LinearGradient(
                          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _err == null
                      ? [
                          BoxShadow(
                            color: AppColors.vendor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: const Text(
                  'Confirm Restock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PRICE SHEET — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _EditPriceSheet extends StatefulWidget {
  final _Listing listing;
  final void Function(double ppb, double dcpt) onConfirm;
  const _EditPriceSheet({required this.listing, required this.onConfirm});

  @override
  State<_EditPriceSheet> createState() => _EditPriceSheetState();
}

class _EditPriceSheetState extends State<_EditPriceSheet> {
  late final TextEditingController _ppbCtrl;
  late final TextEditingController _dcptCtrl;
  String? _ppbErr;
  String? _dcptErr;

  @override
  void initState() {
    super.initState();
    _ppbCtrl = TextEditingController(
      text: widget.listing.pricePerBag.toStringAsFixed(0),
    );
    _dcptCtrl = TextEditingController(
      text: widget.listing.deliveryChargePerTon.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ppbCtrl.dispose();
    _dcptCtrl.dispose();
    super.dispose();
  }

  void _validatePpb(String v) {
    final n = double.tryParse(v);
    setState(
      () => _ppbErr = (n == null || n <= 0) ? 'Enter a valid price' : null,
    );
  }

  void _validateDcpt(String v) {
    final n = double.tryParse(v);
    setState(
      () => _dcptErr = (n == null || n < 0) ? 'Enter a valid charge' : null,
    );
  }

  bool get _valid => _ppbErr == null && _dcptErr == null;

  void _confirm() {
    final ppb = double.tryParse(_ppbCtrl.text);
    final dcpt = double.tryParse(_dcptCtrl.text);
    if (ppb == null || dcpt == null) return;
    if (ppb == widget.listing.pricePerBag &&
        dcpt == widget.listing.deliveryChargePerTon) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(ppb, dcpt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit Prices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.listing.productName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Price per bag',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ppbCtrl,
              onChanged: _validatePpb,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                suffixText: '/ bag',
                suffixStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtleText,
                ),
                errorText: _ppbErr,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delivery charge per ton',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _dcptCtrl,
              onChanged: _validateDcpt,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.titleText,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                suffixText: '/ ton',
                suffixStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtleText,
                ),
                errorText: _dcptErr,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _valid ? _confirm : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _valid
                      ? const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _valid
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: const Text(
                  'Save Prices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String status;
  const _Badge(this.status);

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'active' => (AppColors.vendorMuted, AppColors.vendor, 'Active'),
      'pending' => (AppColors.sandLight, AppColors.sandDark, 'Pending'),
      'rejected' => (const Color(0xFFFEF2F2), AppColors.error, 'Rejected'),
      _ => (AppColors.surfaceAlt, AppColors.subtleText, 'Inactive'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
