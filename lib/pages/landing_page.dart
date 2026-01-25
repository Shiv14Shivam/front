import 'package:flutter/material.dart';
import '../view_type.dart';
import '../widgets/role_card.dart';
import '../theme/app_colors.dart';

class RoleSelectionScreen extends StatelessWidget {
  final Function(ViewType, {String? userType}) onSelectView;

  const RoleSelectionScreen({super.key, required this.onSelectView});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Welcome",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please select your role to continue",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              Row(
                children: [
                  // ===== CUSTOMER =====
                  Expanded(
                    child: RoleCard(
                      title: "Customer",
                      icon: Icons.person_outline,
                      baseColor: AppColors.primary,
                      onTap: () {
                        onSelectView(ViewType.login, userType: 'customer');
                      },
                    ),
                  ),

                  const SizedBox(width: 20),

                  // ===== VENDOR =====
                  Expanded(
                    child: RoleCard(
                      title: "Vendor",
                      icon: Icons.local_shipping_outlined,
                      baseColor: AppColors.vendor,
                      onTap: () {
                        onSelectView(ViewType.login, userType: 'vendor');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
