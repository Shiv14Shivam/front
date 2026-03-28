# Vendor Revenue & Processing Orders Fix

## Information Gathered
- **vendorHome.dart**: Revenue correctly calculated as sum where `payment_status == 'paid'` across all statuses. Stats by `status`: pending/accepted/processing/delivered. Revenue card shows "Revenue (Paid)".
- **vendor_requested_order.dart**: Tabs: All/Pending/Accepted/Processing/Delivered/Declined. Cards show `payment_status` badge ("Paid"/"Pay Later"/"Unpaid") for non-pending. Processing orders have payment badge.
- **api_service.dart**: `getVendorOrders()` fetches data with `order_item.payment_status`, `status`.

**Issues**:
1. VendorHome revenue UI already correct, but processing orders appear "unpaid" in requested_order UI despite `payment_status == 'paid'` → likely backend data or display bug.
2. No explicit "paid" tag in vendorHome (revenue card implies it).

## Plan
1. **lib/pages/vendorHome.dart**: Add paid/unpaid breakdown or confirm revenue only counts paid processing/delivered.
2. **lib/pages/vendor_requested_order.dart**: Ensure processing cards prominently show "PAID" if `payment_status == 'paid'`.
3. Add payment status in stats computation comment if needed.

## Dependent Files
- None new.

## Followup steps
- `flutter analyze`
- `flutter run` test revenue, processing paid display

