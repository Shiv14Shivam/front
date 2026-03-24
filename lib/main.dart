import 'package:flutter/material.dart';
import 'package:front/pages/vendor_profile.dart';

import 'package:front/services/session_manager.dart';
import 'view_type.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/customerHome.dart';
import 'pages/signup.dart';
import 'pages/vendorHome.dart';
import 'pages/customer_profile.dart';
import 'pages/address_form.dart';
import 'pages/edit_address.dart';
import 'pages/ListNewProductPage.dart';
import 'pages/request_order_page.dart';
import 'pages/cart_page.dart';
import 'pages/vendor_requested_order.dart';
import 'pages/vendor_inventory.dart';
import 'pages/notification.dart';
import 'pages/forgotPassword.dart';
import 'pages/resetPassword.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Start with null — show a splash/loader until session check completes
  ViewType? currentView;
  bool _sessionChecked = false;

  String selectedUserType = 'customer';
  String? resetToken;
  String? resetEmail;
  Map<String, dynamic>? pendingOrderData;
  Map<String, dynamic>? pendingEditAddress;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    // ── 1. Handle password-reset deep-link ──────────────────────────────────
    final uri = Uri.base;
    if (uri.fragment.contains('reset-password')) {
      final fragment = uri.fragment;
      final queryString = fragment.contains('?') ? fragment.split('?')[1] : '';
      final params = Uri.splitQueryString(queryString);
      resetToken = params['token'];
      resetEmail = params['email'];
      setState(() {
        currentView = ViewType.resetPassword;
        _sessionChecked = true;
      });
      return;
    }

    // ── 2. Restore session if valid ──────────────────────────────────────────
    final valid = await SessionManager.isSessionValid();
    if (valid) {
      selectedUserType = await SessionManager.getStoredUserType();
      final restoredView = await SessionManager.getStoredView();
      setState(() {
        currentView = restoredView;
        _sessionChecked = true;
      });
    } else {
      await SessionManager.clearSession(); // wipe stale data
      setState(() {
        currentView = ViewType.landing;
        _sessionChecked = true;
      });
    }
  }

  // ── Navigate + persist view ──────────────────────────────────────────────
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
    SessionManager.saveCurrentView(view); // fire-and-forget async is fine here
  }

  @override
  Widget build(BuildContext context) {
    // ── Splash screen while session check runs ───────────────────────────────
    if (!_sessionChecked || currentView == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF15803D)),
          ),
        ),
      );
    }

    Widget child;
    switch (currentView!) {
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
            setState(() => pendingEditAddress = address);
            setView(ViewType.editAddress);
          },
        );
        break;

      case ViewType.vendorProfile:
        child = VendorProfilePage(
          onSelectView: setView,
          onEditAddress: (address) {
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

      case ViewType.editAddress:
        if (pendingEditAddress == null) {
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

      case ViewType.forgotPassword:
        child = ForgotPasswordPage(
          onBackToLogin: () => setView(ViewType.login),
        );
        break;

      case ViewType.resetPassword:
        child = ResetPasswordPage(
          onBackToLogin: () => setView(ViewType.login),
          token: resetToken,
          email: resetEmail,
        );
        break;

      case ViewType.primary:
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
