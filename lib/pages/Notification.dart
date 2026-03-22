import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import 'package:front/services/websocket_service.dart';
import 'package:front/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _Notif {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  _Notif({
    required this.id,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory _Notif.fromJson(Map<String, dynamic> j) {
    return _Notif(
      id: j['id'] as String,
      type: j['type'] as String,
      data: (j['data'] as Map<String, dynamic>?) ?? {},
      isRead: j['read_at'] != null,
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  factory _Notif.fromWsPush(
    Map<String, dynamic> wsData, {
    required bool isVendor,
  }) {
    return _Notif(
      id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
      type: isVendor
          ? 'App\\Notifications\\OrderPlacedNotification'
          : 'App\\Notifications\\OrderStatusUpdatedNotification',
      data: wsData,
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  String get shortType => type.split('\\').last;

  bool get isVendorNotif => shortType == 'OrderPlacedNotification';
  bool get isCustomerNotif => shortType == 'OrderStatusUpdatedNotification';

  String get title => (data['title'] as String?) ?? _defaultTitle;
  String get body => (data['body'] as String?) ?? '';

  String get _defaultTitle {
    switch (shortType) {
      case 'OrderPlacedNotification':
        return 'New Order Received';
      case 'OrderStatusUpdatedNotification':
        return 'Order Status Updated';
      default:
        return 'Notification';
    }
  }

  IconData get icon {
    switch (shortType) {
      case 'OrderPlacedNotification':
        return Icons.shopping_bag_outlined;
      case 'OrderStatusUpdatedNotification':
        final s = data['status'] as String? ?? '';
        if (s == 'accepted') return Icons.check_circle_outline;
        if (s == 'declined') return Icons.cancel_outlined;
        if (s == 'shipped') return Icons.local_shipping_outlined;
        if (s == 'delivered') return Icons.done_all_rounded;
        return Icons.pending_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get accentColor {
    if (isVendorNotif) return AppColors.vendor;
    final s = data['status'] as String? ?? '';
    if (s == 'accepted') return AppColors.success;
    if (s == 'declined') return AppColors.error;
    if (s == 'shipped' || s == 'processing') return AppColors.primary;
    if (s == 'delivered') return AppColors.success;
    return AppColors.warning;
  }

  Color get bgColor {
    if (isVendorNotif) return AppColors.vendorMuted;
    final s = data['status'] as String? ?? '';
    if (s == 'accepted') return const Color(0xFFE8F5E9);
    if (s == 'declined') return const Color(0xFFFFEBEE);
    if (s == 'shipped' || s == 'processing') return AppColors.primaryMuted;
    if (s == 'delivered') return const Color(0xFFE8F5E9);
    return AppColors.sandLight;
  }

  _Notif asRead() => _Notif(
    id: id,
    type: type,
    data: data,
    isRead: true,
    createdAt: createdAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsPage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  final bool isVendor;

  const NotificationsPage({
    super.key,
    required this.onSelectView,
    this.isVendor = true,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  final _api = ApiService();
  final _ws = WebSocketService();

  List<_Notif> _notifs = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  final Map<int, String> _paymentLoading = {};

  WsState _wsState = WsState.disconnected;
  bool _newArrived = false;

  int get _unreadCount => _notifs.where((n) => !n.isRead).length;

  List<_Notif> get _filtered {
    if (_tab == 1) return _notifs.where((n) => !n.isRead).toList();
    return _notifs;
  }

  // Shorthand: use vendor accent or primary depending on role
  Color get _themeAccent =>
      widget.isVendor ? AppColors.vendor : AppColors.primary;

  LinearGradient get _themeGradient =>
      widget.isVendor ? AppColors.vendorGradient : AppColors.primaryGradient;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

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
    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    _loadFromHttp();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ws.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadFromHttp() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.getNotifications();

    if (!mounted) return;

    if (result['success'] == true) {
      final rawList = (result['data'] as List? ?? []);
      setState(() {
        _notifs = rawList
            .map((e) => _Notif.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      _entryController.forward(from: 0);
    } else {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to load notifications';
        _loading = false;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userRaw = prefs.getString('user_data');
    if (token == null || userRaw == null) return;

    Map<String, dynamic> user;
    try {
      user = jsonDecode(userRaw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final userId = user['id'] as int?;
    if (userId == null) return;

    _ws.onStateChange = (WsState s) {
      if (!mounted) return;
      setState(() => _wsState = s);
    };

    _ws.onNotification = (Map<String, dynamic> wsData) {
      if (!mounted) return;
      final notif = _Notif.fromWsPush(wsData, isVendor: widget.isVendor);
      setState(() {
        _notifs.insert(0, notif);
        _newArrived = true;
      });
      _showSnack('🔔 ${notif.title}');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _newArrived = false);
      });
    };

    await _ws.connect(token: token, userId: userId, isVendor: widget.isVendor);
  }

  Future<void> _markAsRead(_Notif notif) async {
    if (notif.isRead) return;
    setState(() {
      final i = _notifs.indexWhere((n) => n.id == notif.id);
      if (i != -1) _notifs[i] = notif.asRead();
    });
    if (!notif.id.startsWith('ws_')) {
      await _api.markNotificationRead(notif.id);
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _notifs = _notifs.map((n) => n.asRead()).toList();
    });
    await _api.markAllNotificationsRead();
    _showSnack('All notifications marked as read');
  }

  // ── Payment actions ───────────────────────────────────────────────────────
  Future<void> _payNow(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    setState(() => _paymentLoading[orderItemId] = 'paying');
    await _markAsRead(notif);

    final result = await _api.payNow(orderItemId);

    if (!mounted) return;
    setState(() => _paymentLoading.remove(orderItemId));

    if (result['success'] == true) {
      _showSnack(
        '✅ ${result['message'] ?? 'Payment successful!'}',
        isSuccess: true,
      );
      setState(() {
        final i = _notifs.indexWhere((n) => n.id == notif.id);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_notifs[i].data);
          updated['payment_status'] = 'paid';
          updated['payment_due'] = 0;
          _notifs[i] = _Notif(
            id: _notifs[i].id,
            type: _notifs[i].type,
            data: updated,
            isRead: true,
            createdAt: _notifs[i].createdAt,
          );
        }
      });
    } else {
      _showSnack(
        '❌ ${result['message'] ?? 'Payment failed'}',
        isSuccess: false,
      );
    }
  }

  Future<void> _payLater(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    setState(() => _paymentLoading[orderItemId] = 'pay_later');
    await _markAsRead(notif);

    final result = await _api.payLater(orderItemId);

    if (!mounted) return;
    setState(() => _paymentLoading.remove(orderItemId));

    if (result['success'] == true) {
      _showSnack('⏰ ${result['message'] ?? 'Pay later set.'}', isSuccess: true);
      setState(() {
        final i = _notifs.indexWhere((n) => n.id == notif.id);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_notifs[i].data);
          updated['payment_status'] = 'pay_later';
          _notifs[i] = _Notif(
            id: _notifs[i].id,
            type: _notifs[i].type,
            data: updated,
            isRead: true,
            createdAt: _notifs[i].createdAt,
          );
        }
      });
    } else {
      _showSnack('❌ ${result['message'] ?? 'Failed'}', isSuccess: false);
    }
  }

  void _showSnack(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  bool get _isDesktopWeb => kIsWeb && !Responsive.isMobile(context);

  @override
  Widget build(BuildContext context) {
    return WebScaffold(
      isVendor: widget.isVendor,
      onSelectView: widget.onSelectView,
      selectedIndex: widget.isVendor ? 4 : 2,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Hide the gradient banner on desktop — sidebar + top bar handle
            // navigation and title already.
            if (!_isDesktopWeb)
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: _buildHeader(),
                ),
              ),

            // On desktop show a slim inline tab/action bar instead
            if (_isDesktopWeb) _buildDesktopTabBar(),

            _buildWsStatusBar(),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _themeAccent,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadFromHttp,
                      color: _themeAccent,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: _buildBody(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop tab bar (replaces the gradient banner on web) ─────────────────
  Widget _buildDesktopTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _desktopTabPill(0, 'All'),
          const SizedBox(width: 8),
          _desktopTabPill(1, 'Unread'),
          const Spacer(),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _themeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _themeAccent.withOpacity(0.2)),
                ),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _themeAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopTabPill(int index, String label) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _themeAccent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.bodyText,
              ),
            ),
            if (index == 1 && _unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.3)
                      : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(gradient: _themeGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onSelectView(
                      widget.isVendor
                          ? ViewType.vendorHome
                          : ViewType.customerHome,
                    ),
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
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'SandHere',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$_unreadCount unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  _tabPill(0, 'All'),
                  const SizedBox(width: 8),
                  _tabPill(1, 'Unread'),
                  const Spacer(),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllAsRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(int index, String label) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? _themeAccent : Colors.white.withOpacity(0.85),
              ),
            ),
            if (index == 1 && _unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? _themeAccent
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── WS status bar ─────────────────────────────────────────────────────────
  Widget _buildWsStatusBar() {
    if (_wsState == WsState.subscribed && _newArrived) {
      return Container(
        height: 32,
        color: _themeAccent.withOpacity(0.08),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _themeAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'New notification arrived',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _themeAccent,
              ),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.subscribed) {
      return Container(
        height: 28,
        color: AppColors.background,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Live — real-time updates on',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.connecting || _wsState == WsState.connected) {
      return Container(
        height: 28,
        color: AppColors.sandLight,
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.sandDark,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Connecting to live updates…',
              style: TextStyle(fontSize: 11, color: AppColors.sandDark),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.failed || _wsState == WsState.authError) {
      return Container(
        height: 28,
        color: const Color(0xFFFEF2F2),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 12,
              color: AppColors.error,
            ),
            const SizedBox(width: 5),
            const Text(
              'Real-time unavailable  ·  ',
              style: TextStyle(fontSize: 11, color: AppColors.error),
            ),
            GestureDetector(
              onTap: _connectWebSocket,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final items = _filtered;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty) _buildEmptyState() else _buildGroupedList(items),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<_Notif> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = items
        .where((n) => _dayOf(n.createdAt).isAtSameMomentAs(today))
        .toList();
    final yesterdayItems = items
        .where((n) => _dayOf(n.createdAt).isAtSameMomentAs(yesterday))
        .toList();
    final olderItems = items
        .where((n) => _dayOf(n.createdAt).isBefore(yesterday))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayItems.isNotEmpty) ...[
          _groupLabel('Today'),
          ..._cards(todayItems),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          _groupLabel('Yesterday'),
          ..._cards(yesterdayItems),
        ],
        if (olderItems.isNotEmpty) ...[
          _groupLabel('Earlier'),
          ..._cards(olderItems),
        ],
      ],
    );
  }

  DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.subtleText,
        letterSpacing: 0.3,
      ),
    ),
  );

  List<Widget> _cards(List<_Notif> items) {
    return List.generate(items.length, (i) {
      final notif = items[i];
      final isWs = notif.id.startsWith('ws_');
      return TweenAnimationBuilder<double>(
        key: ValueKey(notif.id),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: isWs ? 400 : 250 + i * 50),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: isWs
                ? Offset(30 * (1 - value), 0)
                : Offset(0, 14 * (1 - value)),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NotifCard(
            notif: notif,
            paymentLoading: _paymentLoading,
            isVendor: widget.isVendor,
            onTap: () => _markAsRead(notif),
            onPayNow: () => _payNow(notif),
            onPayLater: () => _payLater(notif),
            onViewOrders: () =>
                widget.onSelectView(ViewType.vendorRequestedOrder),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: widget.isVendor
                    ? AppColors.vendorMuted
                    : AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 44,
                color: _themeAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tab == 1 ? 'No unread notifications' : 'No notifications yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tab == 1
                  ? "You're all caught up!"
                  : "We'll notify you when something happens",
              style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
              onTap: _loadFromHttp,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: _themeGradient,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final Map<int, String> paymentLoading;
  final bool isVendor;
  final VoidCallback onTap;
  final VoidCallback onPayNow;
  final VoidCallback onPayLater;
  final VoidCallback onViewOrders;

  const _NotifCard({
    required this.notif,
    required this.paymentLoading,
    required this.isVendor,
    required this.onTap,
    required this.onPayNow,
    required this.onPayLater,
    required this.onViewOrders,
  });

  bool get _shouldShowPayment {
    final status = notif.data['status'] as String? ?? '';
    final payStatus = notif.data['payment_status'] as String? ?? 'unpaid';
    return notif.isCustomerNotif && status == 'accepted' && payStatus != 'paid';
  }

  bool get _shouldShowVendorAction {
    final status = notif.data['status'] as String? ?? '';
    return notif.isVendorNotif && status == 'pending';
  }

  bool get _isPayLaterSet {
    return (notif.data['payment_status'] as String? ?? '') == 'pay_later';
  }

  @override
  Widget build(BuildContext context) {
    final orderItemId = notif.data['order_item_id'] as int?;
    final isPayingNow =
        orderItemId != null && paymentLoading[orderItemId] == 'paying';
    final isPayingLater =
        orderItemId != null && paymentLoading[orderItemId] == 'pay_later';
    final isBusy = isPayingNow || isPayingLater;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? AppColors.border
                : notif.accentColor.withOpacity(0.3),
            width: notif.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notif.isRead
                  ? AppColors.shadowSoft
                  : notif.accentColor.withOpacity(0.07),
              blurRadius: notif.isRead ? 8 : 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? AppColors.surfaceAlt
                          : notif.bgColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      notif.icon,
                      color: notif.isRead
                          ? AppColors.subtleText
                          : notif.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: AppColors.titleText,
                                ),
                              ),
                            ),
                            Text(
                              _timeAgo(notif.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.subtleText,
                              ),
                            ),
                            if (!notif.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: notif.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (notif.body.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            notif.body,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.bodyText,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Status banner ────────────────────────────────────────────
              if (notif.data['status'] != null) ...[
                const SizedBox(height: 10),
                _buildStatusBanner(notif.data['status'] as String, notif.data),
              ],

              // ── Order detail grid ────────────────────────────────────────
              if (_hasOrderDetail) ...[
                const SizedBox(height: 10),
                _buildOrderDetail(),
              ],

              // ── Customer payment buttons ─────────────────────────────────
              if (_shouldShowPayment) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                _buildPaymentActions(
                  orderItemId,
                  isPayingNow,
                  isPayingLater,
                  isBusy,
                ),
              ],

              // ── Pay later confirmation banner ─────────────────────────────
              if (notif.isCustomerNotif &&
                  (notif.data['status'] as String? ?? '') == 'accepted' &&
                  _isPayLaterSet) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sandLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.sand.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.sandDark,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Pay later selected — payment due in 3 days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sandDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Vendor: view order button ────────────────────────────────
              if (_shouldShowVendorAction) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onViewOrders,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'View Order & Accept / Decline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vendor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Status banner ──────────────────────────────────────────────────────────
  Widget _buildStatusBanner(String status, Map<String, dynamic> data) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'accepted':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.success;
        icon = Icons.check_circle_outline;
        text = 'Order accepted — proceed to payment to confirm delivery';
        break;
      case 'declined':
        bg = const Color(0xFFFFEBEE);
        fg = AppColors.error;
        icon = Icons.cancel_outlined;
        final reason =
            data['rejection_reason'] as String? ?? 'No reason provided';
        text = 'Declined: $reason';
        break;
      case 'processing':
        bg = AppColors.primaryMuted;
        fg = AppColors.primary;
        icon = Icons.autorenew_rounded;
        text = 'Your order is being processed';
        break;
      case 'shipped':
        bg = AppColors.primaryMuted;
        fg = AppColors.primaryDark;
        icon = Icons.local_shipping_outlined;
        text = 'Out for delivery!';
        break;
      case 'delivered':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.success;
        icon = Icons.done_all_rounded;
        text = 'Delivered successfully';
        break;
      default:
        bg = AppColors.sandLight;
        fg = AppColors.sandDark;
        icon = Icons.pending_outlined;
        text = 'Awaiting vendor response';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order detail grid ──────────────────────────────────────────────────────
  bool get _hasOrderDetail {
    final d = notif.data;
    return d['order_id'] != null ||
        d['product_name'] != null ||
        d['quantity_unit'] != null;
  }

  Widget _buildOrderDetail() {
    final d = notif.data;

    final rows = <_DetailRow>[];
    if (d['order_id'] != null)
      rows.add(_DetailRow('Order', '#${d['order_id']}'));
    if (d['product_name'] != null && (d['product_name'] as String).isNotEmpty)
      rows.add(_DetailRow('Product', d['product_name'] as String));
    if (d['quantity_unit'] != null)
      rows.add(_DetailRow('Quantity', '${d['quantity_unit']} unit'));
    if (d['subtotal'] != null)
      rows.add(_DetailRow('Subtotal', '₹${d['subtotal']}'));
    if (d['delivery_charge'] != null && (d['delivery_charge'] as num) > 0)
      rows.add(_DetailRow('Delivery', '₹${d['delivery_charge']}'));
    if (d['total_amount'] != null)
      rows.add(_DetailRow('Total', '₹${d['total_amount']}'));
    if (d['distance_km'] != null)
      rows.add(_DetailRow('Distance', '${d['distance_km']} km'));
    if (d['customer_name'] != null && (d['customer_name'] as String).isNotEmpty)
      rows.add(_DetailRow('Customer', d['customer_name'] as String));
    if (d['customer_phone'] != null &&
        (d['customer_phone'] as String).isNotEmpty)
      rows.add(_DetailRow('Phone', d['customer_phone'] as String));
    if (d['delivery_address'] != null &&
        (d['delivery_address'] as String).isNotEmpty)
      rows.add(_DetailRow('Address', d['delivery_address'] as String));
    if (d['vendor_name'] != null && (d['vendor_name'] as String).isNotEmpty)
      rows.add(_DetailRow('Vendor', d['vendor_name'] as String));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: rows
            .map(
              (r) => SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.subtleText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.titleText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Payment action buttons ─────────────────────────────────────────────────
  Widget _buildPaymentActions(
    int? orderItemId,
    bool isPayingNow,
    bool isPayingLater,
    bool isBusy,
  ) {
    final total = notif.data['payment_due'] ?? notif.data['total_amount'] ?? 0;
    final totalStr = '₹$total';

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: isBusy ? null : onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPayingNow
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Pay Now $totalStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: isBusy ? null : onPayLater,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sandDark,
                side: BorderSide(color: AppColors.sand.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPayingLater
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sandDark,
                      ),
                    )
                  : const Text(
                      'Pay Later',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
