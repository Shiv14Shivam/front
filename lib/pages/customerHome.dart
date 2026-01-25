import 'package:flutter/material.dart';
import '../view_type.dart';
import '../theme/app_colors.dart';

class CustomerHomePage extends StatelessWidget {
  final Function(ViewType) onSelectView;

  const CustomerHomePage({super.key, required this.onSelectView});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Home'),
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
