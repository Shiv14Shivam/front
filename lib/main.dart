import 'package:flutter/material.dart';
import 'package:front/pages/primary.dart';

import 'view_type.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/customerHome.dart';
import 'pages/signup.dart';
import 'pages/vendorHome.dart';
import 'pages/requested_order.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ViewType currentView = ViewType.primary;

  /// 🔑 GLOBAL ROLE STATE
  String selectedUserType = 'customer';

  void setView(ViewType view, {String? userType}) {
    setState(() {
      currentView = view;
      if (userType != null) {
        selectedUserType = userType;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (currentView) {
      case ViewType.landing:
        child = RoleSelectionScreen(onSelectView: setView);
        break;

      case ViewType.login:
        child = LoginPage(onSelectView: setView, userType: selectedUserType);
        break;

      case ViewType.signup:
        child = CreateAccountPage(
          userType: selectedUserType,
          onSelectView: setView,
        );
        break;

      case ViewType.customerHome:
        child = CustomerHomePage(onSelectView: setView);
        break;

      case ViewType.vendorHome:
        child = VendorHomePage(
          onSelectView: setView,
        ); // replace later with VendorHomePage
        break;
      case ViewType.primary:
        child = PrimaryPage(onSelectView: setView);
        break;
      case ViewType.requestedOrders:
        child = const RequestedOrdersPage();
        break;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sand Here',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE8F5E9),
      ),
      home: child,
    );
  }
}
