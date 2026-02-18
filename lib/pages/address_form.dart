import 'package:flutter/material.dart';
import 'package:front/view_type.dart';

class AddAddressPage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  final bool isVendor;

  const AddAddressPage({
    super.key,
    required this.onSelectView,
    required this.isVendor,
  });

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();

  final labelController = TextEditingController();
  final line1Controller = TextEditingController();
  final line2Controller = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final pincodeController = TextEditingController();

  bool isDefault = false;

  late List<String> quickLabels;

  @override
  void initState() {
    super.initState();

    quickLabels = widget.isVendor
        ? [
            "Main Warehouse",
            "Office",
            "Secondary Warehouse",
            "Godown",
            "Branch Office",
            "Storage Facility",
          ]
        : [
            "Home",
            "Office",
            "Construction Site",
            "Delivery Address",
            "Work Site",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isVendor
              ? [Colors.green, Colors.green.shade700]
              : [Colors.blue, Colors.purple],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isVendor
                      ? "Add Business Location"
                      : "Add Delivery Address",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Fill in the details below",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              widget.onSelectView(
                widget.isVendor
                    ? ViewType.vendorProfile
                    : ViewType.cutomerProfile,
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= FORM =================
  Widget buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildLabelField(),
          const SizedBox(height: 16),
          buildTextField("Address Line 1", line1Controller),
          const SizedBox(height: 16),
          buildTextField(
            "Address Line 2 (Optional)",
            line2Controller,
            required: false,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: buildTextField("City", cityController)),
              const SizedBox(width: 12),
              Expanded(child: buildTextField("State", stateController)),
            ],
          ),
          const SizedBox(height: 16),
          buildTextField("Pincode", pincodeController),
          const SizedBox(height: 16),
          buildDefaultCheckbox(),
          const SizedBox(height: 24),
          buildButtons(),
        ],
      ),
    );
  }

  // ================= LABEL + QUICK SELECT =================
  Widget buildLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTextField("Address Label", labelController),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickLabels.map((label) {
            return GestureDetector(
              onTap: () => setState(() => labelController.text = label),
              child: Chip(label: Text(label)),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ================= TEXT FIELD =================
  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: required
          ? (value) =>
                value == null || value.isEmpty ? "This field is required" : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ================= DEFAULT CHECKBOX =================
  Widget buildDefaultCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: isDefault,
          onChanged: (value) => setState(() => isDefault = value ?? false),
        ),
        Text(
          widget.isVendor
              ? "Set as default location"
              : "Set as default delivery address",
        ),
      ],
    );
  }

  // ================= BUTTONS =================
  Widget buildButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isVendor ? Colors.green : Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // TODO: Call API here
                Navigator.pop(context);
              }
            },
            child: const Text("Save Address"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onSelectView(
                widget.isVendor
                    ? ViewType.vendorProfile
                    : ViewType.cutomerProfile,
              );
            },

            child: const Text("Cancel"),
          ),
        ),
      ],
    );
  }
}
