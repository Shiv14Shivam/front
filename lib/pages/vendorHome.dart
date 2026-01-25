import 'package:flutter/material.dart';
import '../view_type.dart';
import '../theme/app_colors.dart';

class VendorHomePage extends StatelessWidget {
  final Function(ViewType) onSelectView;

  const VendorHomePage({super.key, required this.onSelectView});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' Vendor Home'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => onSelectView(ViewType.landing),
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
