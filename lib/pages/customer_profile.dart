import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';

class CustomerProfilePage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  final void Function(Map<String, dynamic> address) onEditAddress;

  const CustomerProfilePage({
    required this.onSelectView,
    required this.onEditAddress,
    super.key,
  });

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  List<dynamic> addresses = [];
  bool isLoading = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _accent = AppColors.primary;
  static const _accentMuted = AppColors.primaryMuted;
  static const _gradient = AppColors.primaryGradient;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final profile = await _api.getProfile();
      final addressRes = await _api.getAddresses();
      if (profile['success']) {
        final u = profile['user'];
        nameController.text = u['name'] ?? '';
        emailController.text = u['email'] ?? '';
        phoneController.text = u['phone'] ?? '';
      }
      if (addressRes['success']) {
        setState(
          () => addresses = List<dynamic>.from(addressRes['data'] ?? []),
        );
      }
    } catch (e) {
      if (mounted) _snack('Failed to load data: $e', ok: false);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _fadeCtrl.forward();
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WebScaffold(
      isVendor: false,
      onSelectView: widget.onSelectView,
      selectedIndex: 3,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: isLoading
            ? _loader()
            : FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _profileBanner(),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            children: [
                              _personalCard(),
                              const SizedBox(height: 20),
                              _addressesCard(),
                              const SizedBox(height: 20),
                              /*_quickActionsCard(),
                              const SizedBox(height: 28),*/
                              _logoutBtn(),
                              const SizedBox(height: 24),
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

  Widget _loader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text(
          'Loading...',
          style: TextStyle(color: AppColors.bodyText, fontSize: 14),
        ),
      ],
    ),
  );

  // ── Profile banner ─────────────────────────────────────────────────────────
  Widget _profileBanner() {
    final initial = nameController.text.isNotEmpty
        ? nameController.text[0].toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _gradient),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotPainter())),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: back + edit
                  Row(
                    children: [
                      _iconBtn(
                        Icons.arrow_back_ios_new_rounded,
                        () => widget.onSelectView(ViewType.customerHome),
                      ),
                      const Spacer(),
                      _iconBtn(Icons.edit_outlined, _showEditDialog),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Avatar + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar circle with initial
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nameController.text.isEmpty
                                  ? 'User'
                                  : nameController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emailController.text,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _whitePill("👷  Customer"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    ),
  );

  Widget _whitePill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Personal info card ─────────────────────────────────────────────────────
  Widget _personalCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader(
          'Personal Information',
          Icons.person_outline,
          onEdit: _showEditDialog,
        ),
        const SizedBox(height: 4),
        _infoRow(Icons.person_outline, 'Full Name', nameController.text),
        _infoRow(Icons.email_outlined, 'Email Address', emailController.text),
        _infoRow(
          Icons.phone_outlined,
          'Mobile Number',
          phoneController.text,
          isLast: true,
        ),
      ],
    ),
  );

  // ── Addresses card ─────────────────────────────────────────────────────────
  Widget _addressesCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader(
          'Delivery Addresses',
          Icons.location_on_outlined,
          onAdd: () async {
            widget.onSelectView(ViewType.addressForm);
            await Future.delayed(const Duration(milliseconds: 800));
            _fetchData();
          },
        ),
        const SizedBox(height: 4),
        if (addresses.isEmpty)
          _emptyState(
            Icons.location_on_outlined,
            'No addresses yet',
            'Add your first delivery address',
          )
        else
          ...addresses.map(
            (a) => _addressTile(Map<String, dynamic>.from(a as Map)),
          ),
      ],
    ),
  );

  Widget _addressTile(Map<String, dynamic> address) {
    final isDefault =
        address['is_default'] == true || address['is_default'] == 1;
    final hasCoords =
        address['latitude'] != null && address['longitude'] != null;

    final lines = [
      address['address_line_1'] ?? '',
      address['address_line_2'] ?? '',
      '${address['city'] ?? ''}, ${address['state'] ?? ''}',
      address['pincode'] ?? '',
    ].where((l) => l.trim().isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault ? _accent.withOpacity(0.04) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault ? _accent.withOpacity(0.3) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDefault ? Icons.star_rounded : Icons.location_on_outlined,
                size: 15,
                color: isDefault ? AppColors.warning : AppColors.bodyText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address['label'] ?? 'Home',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDefault ? _accent : AppColors.titleText,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            lines,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                hasCoords ? Icons.my_location : Icons.location_off,
                size: 11,
                color: hasCoords ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 5),
              Text(
                hasCoords
                    ? 'Location pinned'
                    : 'No pin — tap Edit to add location',
                style: TextStyle(
                  fontSize: 11,
                  color: hasCoords ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isDefault) ...[
                _actionBtn(
                  'Set Default',
                  Icons.star_border_rounded,
                  AppColors.warning,
                  () async {
                    await _api.setDefaultAddress(address['id'] as int);
                    _fetchData();
                  },
                ),
                const SizedBox(width: 14),
              ],
              _actionBtn(
                'Edit',
                Icons.edit_outlined,
                _accent,
                () => widget.onEditAddress(address),
              ),
              const SizedBox(width: 14),
              _actionBtn(
                'Remove',
                Icons.delete_outline_rounded,
                AppColors.error,
                () => _deleteAddress(address),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick actions card ─────────────────────────────────────────────────────
  /* Widget _quickActionsCard() {
    final items = [
      (Icons.receipt_long_outlined, 'Order History', 'View past orders'),
      (Icons.card_giftcard_outlined, 'Rewards', 'Points & benefits'),
      (Icons.support_agent_outlined, 'Support', 'Help & FAQs'),
      (Icons.settings_outlined, 'Settings', 'Account preferences'),
    ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Quick Actions', Icons.grid_view_rounded),
          const SizedBox(height: 4),
          ...items.asMap().entries.map(
            (e) => Column(
              children: [
                _actionTile(e.value.$1, e.value.$2, e.value.$3),
                if (e.key < items.length - 1)
                  Divider(height: 1, color: AppColors.border.withOpacity(0.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }*/

  // ── Logout ─────────────────────────────────────────────────────────────────
  Widget _logoutBtn() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () async {
        try {
          final res = await _api.logout();
          if (res['success'] && mounted) widget.onSelectView(ViewType.login);
        } catch (_) {
          if (mounted) _snack('Logout failed', ok: false);
        }
      },
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text(
        'Sign Out',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withOpacity(0.4), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  // ── Edit dialog ────────────────────────────────────────────────────────────
  void _showEditDialog() {
    final namE = TextEditingController(text: nameController.text);
    final email = TextEditingController(text: emailController.text);
    final phone = TextEditingController(text: phoneController.text);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  gradient: _gradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _dlgField(namE, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 14),
                    _dlgField(email, 'Email Address', Icons.email_outlined),
                    const SizedBox(height: 14),
                    _dlgField(phone, 'Mobile Number', Icons.phone_outlined),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _outlineBtn(
                            'Cancel',
                            () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _primaryBtn('Save Changes', () async {
                            Navigator.pop(ctx);
                            final res = await _api.updateProfile(
                              namE.text.trim(),
                              email.text.trim(),
                              phone.text.trim(),
                            );
                            if (res['success'] && mounted) {
                              setState(() {
                                nameController.text = namE.text.trim();
                                emailController.text = email.text.trim();
                                phoneController.text = phone.text.trim();
                              });
                              _snack('Profile updated', ok: true);
                            } else if (mounted) {
                              _snack(
                                res['message'] ?? 'Update failed',
                                ok: false,
                              );
                            }
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      namE.dispose();
      email.dispose();
      phone.dispose();
    });
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Address',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Remove "${address["label"] ?? "this address"}"?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _api.deleteAddress(address['id'] as int);
      _fetchData();
    }
  }

  void _snack(String msg, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  Widget _cardHeader(
    String title,
    IconData icon, {
    VoidCallback? onEdit,
    VoidCallback? onAdd,
  }) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _accentMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _accent, size: 16),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.titleText,
        ),
      ),
      const Spacer(),
      if (onEdit != null)
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'Edit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (onAdd != null)
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'Add New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.subtleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? 'Not provided' : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty
                          ? AppColors.subtleText
                          : AppColors.titleText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isLast) Divider(height: 1, color: AppColors.border.withOpacity(0.6)),
    ],
  );

  Widget _emptyState(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: _accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
          ),
        ],
      ),
    ),
  );

  Widget _actionBtn(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _dlgField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, color: AppColors.titleText),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.bodyText),
          prefixIcon: Icon(icon, color: _accent, size: 18),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.8),
          ),
        ),
      );

  Widget _primaryBtn(String text, VoidCallback onTap) => SizedBox(
    height: 46,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _outlineBtn(String text, VoidCallback onTap) => SizedBox(
    height: 46,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.bodyText,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.08);
    for (double x = 0; x < size.width; x += 24)
      for (double y = 0; y < size.height; y += 24)
        canvas.drawCircle(Offset(x, y), 1.5, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
