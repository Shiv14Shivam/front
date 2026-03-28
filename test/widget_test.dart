// Unit tests for SandHere vendor dashboard business logic.
//
// These test pure Dart functions extracted from vendorHome.dart:
//   • _toDouble  — safe type conversion for API values
//   • _fmtRevenue — revenue display formatting
//   • revenue accumulation — the loop that sums paid orders (was broken by wrong JSON key)
//
// Run with:  flutter test

import 'package:flutter_test/flutter_test.dart';

// ── Inline the helpers (copied from vendorHome.dart) so they're testable ─────

double toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

String fmtRevenue(double a) {
  if (a >= 10000000) return '₹${(a / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000) return '₹${(a / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '₹${(a / 1000).toStringAsFixed(1)}K';
  return '₹${a.toStringAsFixed(0)}';
}

double calcRevenue(List<Map<String, dynamic>> rawList) {
  double revenue = 0.0;
  for (final item in rawList) {
    // Key must be 'order_item' (singular) — this was the bug that caused ₹0
    final oi = (item['order_item'] as Map<String, dynamic>?) ?? {};
    final payStatus = oi['payment_status'] as String? ?? 'unpaid';
    final subtotal = toDouble(oi['subtotal']);
    final dc = toDouble(oi['delivery_charge'] ?? 0);
    if (payStatus == 'paid') revenue += subtotal + dc;
  }
  return revenue;
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ── _toDouble tests ──────────────────────────────────────────────────────
  group('toDouble', () {
    test('returns 0.0 for null', () {
      expect(toDouble(null), 0.0);
    });

    test('handles double input', () {
      expect(toDouble(1234.56), 1234.56);
    });

    test('handles int input', () {
      expect(toDouble(500), 500.0);
    });

    test('handles numeric string', () {
      expect(toDouble('750.25'), 750.25);
    });

    test('returns 0.0 for non-numeric string', () {
      expect(toDouble('abc'), 0.0);
    });
  });

  // ── _fmtRevenue tests ─────────────────────────────────────────────────────
  group('fmtRevenue', () {
    test('formats zero correctly', () {
      expect(fmtRevenue(0), '₹0');
    });

    test('formats thousands as K', () {
      expect(fmtRevenue(5000), '₹5.0K');
    });

    test('formats lakhs as L', () {
      expect(fmtRevenue(250000), '₹2.5L');
    });

    test('formats crores as Cr', () {
      expect(fmtRevenue(10000000), '₹1.0Cr');
    });

    test('formats sub-thousand as plain rupees', () {
      expect(fmtRevenue(850), '₹850');
    });
  });

  // ── Revenue accumulation loop ─────────────────────────────────────────────
  group('calcRevenue', () {
    test('returns 0 when list is empty', () {
      expect(calcRevenue([]), 0.0);
    });

    test('counts only paid orders', () {
      final orders = [
        {'order_item': {'payment_status': 'paid', 'subtotal': 1000.0, 'delivery_charge': 200.0}},
        {'order_item': {'payment_status': 'unpaid', 'subtotal': 500.0, 'delivery_charge': 100.0}},
        {'order_item': {'payment_status': 'pay_later', 'subtotal': 800.0, 'delivery_charge': 150.0}},
      ];
      // Only first item (paid) should be included: 1000 + 200 = 1200
      expect(calcRevenue(orders), 1200.0);
    });

    test('sums multiple paid orders including delivery', () {
      final orders = [
        {'order_item': {'payment_status': 'paid', 'subtotal': 1000.0, 'delivery_charge': 200.0}},
        {'order_item': {'payment_status': 'paid', 'subtotal': 3000.0, 'delivery_charge': 500.0}},
      ];
      // 1200 + 3500 = 4700
      expect(calcRevenue(orders), 4700.0);
    });

    test('wrong key order_items (bug) gives zero revenue', () {
      // This proves the bug: using 'order_items' (plural) returns empty map → revenue = 0
      final orders = [
        {'order_items': {'payment_status': 'paid', 'subtotal': 1000.0, 'delivery_charge': 200.0}},
      ];
      // 'order_item' key is missing → oi is {} → payStatus defaults to 'unpaid'
      expect(calcRevenue(orders), 0.0);
    });

    test('correct key order_item (fix) gives correct revenue', () {
      final orders = [
        {'order_item': {'payment_status': 'paid', 'subtotal': 1000.0, 'delivery_charge': 200.0}},
      ];
      expect(calcRevenue(orders), 1200.0);
    });
  });
}
