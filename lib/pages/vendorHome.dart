import 'package:flutter/material.dart';
import '../view_type.dart';
import '../widgets/logo.dart';
// import 'requested_orders_page.dart'; // uncomment when you add that page

class VendorHomePage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  const VendorHomePage({super.key, required this.onSelectView});

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFFF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.yellow.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppLogo(size: 32),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Vendor Dashboard", style: TextStyle(color: Colors.green)),
                Text(
                  "BuildMart Supplier",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.black),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.green,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            widget.onSelectView(ViewType.vendorProfile);
          }
        },
      ),

      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// ---- STATS GRID ----
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: const [
                    StatCard(
                      "156",
                      "Total Orders",
                      Icons.inventory,
                      Colors.blue,
                    ),
                    StatCard("23", "Pending", Icons.access_time, Colors.orange),
                    StatCard(
                      "98",
                      "Dispatched",
                      Icons.local_shipping,
                      Colors.green,
                    ),
                    StatCard(
                      "₹24.5L",
                      "Revenue",
                      Icons.currency_rupee,
                      Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// ---- LOW STOCK ----
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Low Stock Alert",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "8 items need restocking",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Quick Actions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                /// ---- QUICK ACTION BUTTONS ----
                ActionTile(
                  icon: Icons.access_time,
                  title: "Requested Orders",
                  subtitle: "23 orders waiting for approval",
                  count: "23",
                  color: Colors.orange,
                  onTap: () {
                    widget.onSelectView(ViewType.requestedOrders);
                  },
                ),

                ActionTile(
                  icon: Icons.local_shipping,
                  title: "Dispatched Orders",
                  subtitle: "98 orders in transit",
                  count: "98",
                  color: Colors.green,
                  onTap: () {},
                ),

                ActionTile(
                  icon: Icons.inventory,
                  title: "Inventory Management",
                  subtitle: "View and manage stock levels",
                  count: "8",
                  color: Colors.blue,
                  onTap: () {},
                ),

                ActionTile(
                  icon: Icons.analytics,
                  title: "Analytics & Reports",
                  subtitle: "View sales and performance",
                  color: Colors.purple,
                  onTap: () {},
                ),

                ActionTile(
                  icon: Icons.add,
                  title: "Add Your Product",
                  subtitle: "Add new product to your store",
                  color: Colors.lightGreen,
                  onTap: () {
                    widget.onSelectView(ViewType.listNewProduct);
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------- SMALL WIDGETS --------

class StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const StatCard(this.value, this.label, this.icon, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? count;
  final Color color;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(count!, style: TextStyle(color: color)),
              ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}
