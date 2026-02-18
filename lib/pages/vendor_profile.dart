import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_card.dart';
import '../widgets/info_tile.dart';
import '../widgets/location_card.dart';
import '../view_type.dart';

class VendorProfilePage extends StatelessWidget {
  final Function(ViewType) onSelectView;

  const VendorProfilePage({super.key, required this.onSelectView});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 60),
            _buildStatsSection(),
            const SizedBox(height: 20),
            _buildBusinessInfoSection(),
            const SizedBox(height: 20),
            _buildBusinessLocationsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.08),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 35,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "BuildMart Supplier",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Construction Materials Supplier",
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Chip(
                            label: Text("Verified Seller"),
                            backgroundColor: Color(0xFFE8F5E9),
                          ),
                          SizedBox(width: 8),
                          Chip(label: Text("Since 2022")),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, color: Colors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatCard(icon: Icons.inventory, value: "248", label: "Products"),
          StatCard(icon: Icons.star, value: "4.8", label: "Rating"),
          StatCard(icon: Icons.trending_up, value: "1.2K", label: "Orders"),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: "Business Information",
        icon: Icons.business,
        children: [
          InfoTile(title: "Business Name", value: "BuildMart Supplier"),
          InfoTile(title: "Owner Name", value: "Suresh Patel"),
          InfoTile(title: "Email", value: "contact@buildmart.com"),
          InfoTile(title: "Phone", value: "+91 98765 12345"),
          InfoTile(title: "GST Number", value: "29ABCDE1234F1Z5"),
          InfoTile(
            title: "Business Type",
            value: "Construction Materials Supplier",
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessLocationsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: "Business Locations",
        icon: Icons.location_on,
        showAdd: true,

        // 👇 Navigate using your ViewType system
        onAddTap: () {
          onSelectView(ViewType.addressForm);
        },

        children: const [
          LocationCard(
            title: "Warehouse & Office",
            address:
                "Plot No. 45, Sector 18\nIndustrial Area, Near Highway\nGurgaon, Haryana - 122015",
            isDefault: true,
          ),
          SizedBox(height: 12),
          LocationCard(
            title: "Secondary Warehouse",
            address:
                "Godown No. 12, MIDC Area\nPhase 3, Logistic Park\nFaridabad, Haryana - 121003",
            isDefault: false,
          ),
        ],
      ),
    );
  }
}
