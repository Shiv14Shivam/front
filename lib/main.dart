import 'package:flutter/material.dart';
import 'package:front/pages/primary.dart';
import 'package:front/pages/vendor_profile.dart';

import 'view_type.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/customerHome.dart';
import 'pages/signup.dart';
import 'pages/vendorHome.dart';
import 'pages/requested_order.dart';
import 'pages/customer_profile.dart';
import 'pages/address_form.dart';
import 'pages/ListNewProductPage.dart';
import 'pages/request_order_page.dart';
import 'pages/cart_page.dart';

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
  Map<String, dynamic>? pendingOrderData;

  void setView(
    ViewType view, {
    Map<String, dynamic>? orderData,
    String? userType,
  }) {
    setState(() {
      currentView = view;
      if (userType != null) {
        selectedUserType = userType;
      }
      if (orderData != null) {
        pendingOrderData = orderData;
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
        child = VendorHomePage(onSelectView: setView);
        break;

      case ViewType.primary:
        child = PrimaryPage(onSelectView: setView);
        break;

      case ViewType.requestedOrders:
        child = const RequestedOrdersPage();
        break;

      case ViewType.cutomerProfile:
        child = CustomerProfilePage(onSelectView: setView);
        break;

      case ViewType.vendorProfile:
        child = VendorProfilePage(onSelectView: setView);
        break;

      case ViewType.addressForm:
        child = AddAddressPage(
          onSelectView: setView,
          isVendor: selectedUserType == 'vendor',
        );
        break;

      case ViewType.listNewProduct:
        child = AddProductPage(onSelectView: setView);
        break;

      case ViewType.requestOrder:
        // Guard: if somehow we land here without data, go back home
        if (pendingOrderData == null) {
          child = CustomerHomePage(onSelectView: setView);
        } else {
          child = RequestOrderPage(
            onSelectView: setView,
            listing: pendingOrderData!["listing"],
            quantity: pendingOrderData!["quantity"],
            distance: pendingOrderData!["distance"],
            totalCost: pendingOrderData!["totalCost"],
          );
        }
        break;

      // ✅ Only this case changed — reads cartItems from pendingOrderData
      case ViewType.cart:
        child = CartPage(onSelectView: setView);
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
