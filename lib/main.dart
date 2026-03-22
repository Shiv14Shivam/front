import 'package:flutter/material.dart';

import 'package:front/pages/vendor_profile.dart';

import 'view_type.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/customerHome.dart';
import 'pages/signup.dart';
import 'pages/vendorHome.dart';
import 'pages/customer_profile.dart';
import 'pages/address_form.dart';
import 'pages/edit_address.dart'; // ← NEW
import 'pages/ListNewProductPage.dart';
import 'pages/request_order_page.dart';
import 'pages/cart_page.dart';
import 'pages/vendor_requested_order.dart';
import 'pages/vendor_inventory.dart';
import 'pages/notification.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ViewType currentView = ViewType.landing;

  String selectedUserType = 'customer';
  Map<String, dynamic>? pendingOrderData;

  // Holds the address being edited — set by profile pages before navigating
  Map<String, dynamic>? pendingEditAddress; // ← NEW

  void setView(
    ViewType view, {
    Map<String, dynamic>? orderData,
    String? userType,
  }) {
    setState(() {
      currentView = view;
      if (userType != null) selectedUserType = userType;
      if (orderData != null) pendingOrderData = orderData;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (currentView) {
      case ViewType.landing:
        child = SandHereWebsite(
          onSelectView: (viewType, {userType}) {
            setView(ViewType.login, userType: userType);
          },
        );
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

      case ViewType.cutomerProfile:
        child = CustomerProfilePage(
          onSelectView: setView,
          onEditAddress: (address) {
            // ← NEW callback
            setState(() => pendingEditAddress = address);
            setView(ViewType.editAddress);
          },
        );
        break;

      case ViewType.vendorProfile:
        child = VendorProfilePage(
          onSelectView: setView,
          onEditAddress: (address) {
            // ← NEW callback
            setState(() => pendingEditAddress = address);
            setView(ViewType.editAddress);
          },
        );
        break;

      case ViewType.addressForm:
        child = AddAddressPage(
          onSelectView: setView,
          isVendor: selectedUserType == 'vendor',
        );
        break;

      // ── NEW ───────────────────────────────────────────────────────────────
      case ViewType.editAddress:
        if (pendingEditAddress == null) {
          // Safety fallback — should never happen
          child = selectedUserType == 'vendor'
              ? VendorProfilePage(
                  onSelectView: setView,
                  onEditAddress: (a) {
                    setState(() => pendingEditAddress = a);
                    setView(ViewType.editAddress);
                  },
                )
              : CustomerProfilePage(
                  onSelectView: setView,
                  onEditAddress: (a) {
                    setState(() => pendingEditAddress = a);
                    setView(ViewType.editAddress);
                  },
                );
        } else {
          child = EditAddressPage(
            onSelectView: setView,
            isVendor: selectedUserType == 'vendor',
            address: pendingEditAddress!,
          );
        }
        break;

      case ViewType.listNewProduct:
        child = AddProductPage(onSelectView: setView);
        break;

      case ViewType.requestOrder:
        if (pendingOrderData == null) {
          child = CustomerHomePage(onSelectView: setView);
        } else {
          child = RequestOrderPage(
            onSelectView: setView,
            listing: pendingOrderData!['listing'],
            quantity: pendingOrderData!['quantity'],
            distance: pendingOrderData!['distance'],
            totalCost: pendingOrderData!['totalCost'],
          );
        }
        break;

      case ViewType.cart:
        child = CartPage(onSelectView: setView);
        break;

      case ViewType.vendorRequestedOrder:
        child = VendorRequestedOrder(onSelectView: setView);
        break;

      case ViewType.vendorInventory:
        child = VendorInventoryPage(onSelectView: setView);
        break;

      case ViewType.notifications:
        child = NotificationsPage(
          onSelectView: setView,
          isVendor: selectedUserType == 'vendor',
        );
        break;
      case ViewType.primary:
        // TODO: Handle this case.
        throw UnimplementedError();
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
