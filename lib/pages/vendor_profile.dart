import 'package:flutter/material.dart';
import '../view_type.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

import '../widgets/web_scaffold.dart';

class VendorProfilePage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  final void Function(Map<String, dynamic> address) onEditAddress;

  const VendorProfilePage({
    super.key,
    required this.onSelectView,
    required this.onEditAddress,
  });

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  Map<String, dynamic>? user;
  Map<String, dynamic>? vendor;
  List<dynamic> addresses = [];
  bool isLoading = true;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final firmController = TextEditingController();
  final businessTypeController = TextEditingController();
  final gstController = TextEditingController();
  final emailController = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _accent = AppColors.vendor;
  static const _accentMuted = AppColors.vendorMuted;
  static const _gradient = AppColors.vendorGradient;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    nameController.dispose();
    phoneController.dispose();
    firmController.dispose();
    businessTypeController.dispose();
    gstController.dispose();
    emailController.dispose();
    super.dispose();
  }

  String get _year {
    try {
      final c = user?['created_at'];
      if (c == null) return '';
      return DateTime.parse(c.toString()).year.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadData() async {
    final profileRes = await _api.getProfile();
    final addressRes = await _api.getAddresses();
    if (profileRes['success']) {
      user = profileRes['user'];
      vendor = user?['vendor'];
      nameController.text = user?['name'] ?? '';
      emailController.text = user?['email'] ?? '';
      phoneController.text = user?['phone'] ?? '';
      firmController.text = vendor?['firm_name'] ?? '';
      businessTypeController.text = vendor?['business_type'] ?? '';
      gstController.text = vendor?['gst_number'] ?? '';
    }
    if (addressRes['success']) {
      addresses = List.from(addressRes['data']);
    }
    if (mounted) {
      setState(() => isLoading = false);
      _fadeCtrl.forward();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 5,
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
                              _businessCard(),
                              const SizedBox(height: 20),
                              _locationsCard(),
                              const SizedBox(height: 28),
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
    final initials = firmController.text.isNotEmpty
        ? firmController.text[0].toUpperCase()
        : nameController.text.isNotEmpty
        ? nameController.text[0].toUpperCase()
        : 'V';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _gradient),
      child: Stack(
        children: [
          // Dot texture
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
                        () => widget.onSelectView(ViewType.vendorHome),
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
                      // Avatar circle
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
                            initials,
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
                              firmController.text.isNotEmpty
                                  ? firmController.text
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
                              businessTypeController.text.isNotEmpty
                                  ? businessTypeController.text
                                  : 'Construction Supplier',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chips
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _whitePill("🏪  Vendor"),
                          if (_year.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _whitePill("Since $_year"),
                          ],
                        ],
                      ),
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

  // ── Business card ──────────────────────────────────────────────────────────
  Widget _businessCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader(
          'Business Information',
          Icons.business_outlined,
          onEdit: _showEditDialog,
        ),
        const SizedBox(height: 4),
        _infoRow(Icons.business_outlined, 'Firm Name', firmController.text),
        _infoRow(Icons.person_outline, 'Owner Name', nameController.text),
        _infoRow(Icons.email_outlined, 'Email', emailController.text),
        _infoRow(Icons.phone_outlined, 'Phone', phoneController.text),
        _infoRow(Icons.receipt_outlined, 'GST Number', gstController.text),
        _infoRow(
          Icons.category_outlined,
          'Business Type',
          businessTypeController.text,
          isLast: true,
        ),
      ],
    ),
  );

  // ── Locations card ─────────────────────────────────────────────────────────
  Widget _locationsCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHeader(
          'Business Locations',
          Icons.location_on_outlined,
          onAdd: () => widget.onSelectView(ViewType.addressForm),
        ),
        const SizedBox(height: 4),
        if (addresses.isEmpty)
          _emptyState(
            Icons.location_on_outlined,
            'No locations added',
            'Add your first business address',
          )
        else
          ...addresses.map(
            (a) => _locationTile(Map<String, dynamic>.from(a as Map)),
          ),
      ],
    ),
  );

  Widget _locationTile(Map<String, dynamic> address) {
    final isDefault = address['is_default'] == true;
    final hasCoords =
        address['latitude'] != null && address['longitude'] != null;

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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDefault
                      ? _accent.withOpacity(0.1)
                      : AppColors.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isDefault ? Icons.star_rounded : Icons.location_on_outlined,
                  size: 15,
                  color: isDefault ? _accent : AppColors.bodyText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  address['label'] ?? 'Location',
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              '${address["address_line_1"] ?? ""}\n'
              '${address["city"] ?? ""}, ${address["state"] ?? ""} - ${address["pincode"] ?? ""}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.bodyText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
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
                    _loadData();
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

  // ── Logout ─────────────────────────────────────────────────────────────────
  Widget _logoutBtn() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () async {
        final res = await _api.logout();
        if (res['success'] && mounted) widget.onSelectView(ViewType.login);
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
    final ctrls = {
      'firm': TextEditingController(text: firmController.text),
      'name': TextEditingController(text: nameController.text),
      'email': TextEditingController(text: emailController.text),
      'phone': TextEditingController(text: phoneController.text),
      'gst': TextEditingController(text: gstController.text),
      'business': TextEditingController(text: businessTypeController.text),
    };

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
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
              // Dialog header
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
                      'Edit Business Profile',
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _dlgField(
                        ctrls['firm']!,
                        'Firm Name',
                        Icons.business_outlined,
                      ),
                      const SizedBox(height: 14),
                      _dlgField(
                        ctrls['name']!,
                        'Owner Name',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      _dlgField(
                        ctrls['email']!,
                        'Email Address',
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 14),
                      _dlgField(
                        ctrls['phone']!,
                        'Phone Number',
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 14),
                      _dlgField(
                        ctrls['gst']!,
                        'GST Number',
                        Icons.receipt_outlined,
                      ),
                      const SizedBox(height: 14),
                      _dlgField(
                        ctrls['business']!,
                        'Business Type',
                        Icons.category_outlined,
                      ),
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
                                ctrls['name']!.text.trim(),
                                ctrls['email']!.text.trim(),
                                ctrls['phone']!.text.trim(),
                                firmName: ctrls['firm']!.text.trim(),
                                businessType: ctrls['business']!.text.trim(),
                                gstNumber: ctrls['gst']!.text.trim(),
                              );
                              if (res['success'] && mounted) {
                                _snack('Profile updated', ok: true);
                                await _loadData();
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
              ),
            ],
          ),
        ),
      ),
    ).then((_) => ctrls.values.forEach((c) => c.dispose()));
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Location',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Remove "${address["label"] ?? "this location"}"?\nThis cannot be undone.',
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
      _loadData();
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
