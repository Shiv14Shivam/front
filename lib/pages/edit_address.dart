import 'package:flutter/material.dart';
import 'package:front/view_type.dart';
import 'package:front/services/api_service.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker.dart';
import '../theme/app_colors.dart';
import '../widgets/web_layout.dart';

class EditAddressPage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  final bool isVendor;
  final Map<String, dynamic> address;

  const EditAddressPage({
    super.key,
    required this.onSelectView,
    required this.isVendor,
    required this.address,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  late final TextEditingController labelController;
  late final TextEditingController line1Controller;
  late final TextEditingController line2Controller;
  late final TextEditingController cityController;
  late final TextEditingController stateController;
  late final TextEditingController pincodeController;

  bool isDefault = false;
  bool isLoading = false;

  double? _lat;
  double? _lng;

  late List<String> quickLabels;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    labelController = TextEditingController(text: a['label'] ?? '');
    line1Controller = TextEditingController(text: a['address_line_1'] ?? '');
    line2Controller = TextEditingController(text: a['address_line_2'] ?? '');
    cityController = TextEditingController(text: a['city'] ?? '');
    stateController = TextEditingController(text: a['state'] ?? '');
    pincodeController = TextEditingController(text: a['pincode'] ?? '');
    isDefault = a['is_default'] == true || a['is_default'] == 1;
    _lat = double.tryParse(a['latitude']?.toString() ?? '');
    _lng = double.tryParse(a['longitude']?.toString() ?? '');

    quickLabels = widget.isVendor
        ? [
            'Main Warehouse',
            'Office',
            'Secondary Warehouse',
            'Godown',
            'Branch Office',
            'Storage Facility',
          ]
        : [
            'Home',
            'Office',
            'Construction Site',
            'Delivery Address',
            'Work Site',
          ];
  }

  @override
  void dispose() {
    labelController.dispose();
    line1Controller.dispose();
    line2Controller.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  // ── Map picker ─────────────────────────────────────────────────────────────
  Future<void> _openMapPicker() async {
    final LatLng? picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initial: (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null,
        ),
        fullscreenDialog: true,
      ),
    );
    if (picked != null) {
      setState(() {
        _lat = picked.latitude;
        _lng = picked.longitude;
      });
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please pin your location on the map so distances can be calculated.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await _api.updateAddress(
      widget.address['id'] as int,
      label: labelController.text.trim(),
      line1: line1Controller.text.trim(),
      line2: line2Controller.text.trim().isEmpty
          ? null
          : line2Controller.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim(),
      pincode: pincodeController.text.trim(),
      isDefault: isDefault,
      latitude: _lat,
      longitude: _lng,
    );

    setState(() => isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSelectView(
          widget.isVendor ? ViewType.vendorProfile : ViewType.customerProfile,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update address'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isVendor
        ? AppColors.success
        : AppColors.primary;

    return WebLayout(
      maxWidth: 640,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(accent),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildForm(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent, accent.withOpacity(0.75)]),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_location_alt_outlined,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isVendor
                      ? 'Edit Business Location'
                      : 'Edit Delivery Address',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Update the details below',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => widget.onSelectView(
              widget.isVendor
                  ? ViewType.vendorProfile
                  : ViewType.customerProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(Color accent) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapPinCard(accent),
          const SizedBox(height: 20),
          _buildLabelField(),
          const SizedBox(height: 16),
          _buildTextField('Address Line 1', line1Controller),
          const SizedBox(height: 16),
          _buildTextField(
            'Address Line 2 (Optional)',
            line2Controller,
            required: false,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField('City', cityController)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('State', stateController)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Pincode', pincodeController),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: isDefault,
                activeColor: accent,
                onChanged: (v) => setState(() => isDefault = v ?? false),
              ),
              Text(
                widget.isVendor
                    ? 'Set as default location'
                    : 'Set as default delivery address',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : _save,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Address',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onSelectView(
                    widget.isVendor
                        ? ViewType.vendorProfile
                        : ViewType.customerProfile,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMapPinCard(Color accent) {
    final bool pinned = _lat != null && _lng != null;
    return GestureDetector(
      onTap: _openMapPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pinned ? accent.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pinned
                ? accent.withOpacity(0.45)
                : Colors.redAccent.withOpacity(0.4),
            width: pinned ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                pinned
                    ? Icons.location_on_rounded
                    : Icons.add_location_alt_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pinned ? 'Location pinned ✓' : 'Pin your location on map *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: pinned ? accent : AppColors.titleText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pinned
                        ? '${_lat!.toStringAsFixed(5)},  '
                              '${_lng!.toStringAsFixed(5)}'
                        : 'Tap to open map — re-pin to update location',
                    style: TextStyle(
                      fontSize: 12,
                      color: pinned
                          ? AppColors.bodyText
                          : Colors.redAccent.shade200,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              pinned
                  ? Icons.edit_location_alt_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.subtleText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Address Label', labelController),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickLabels
              .map(
                (l) => GestureDetector(
                  onTap: () => setState(() => labelController.text = l),
                  child: Chip(label: Text(l)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'This field is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
