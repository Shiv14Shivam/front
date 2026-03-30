# SandHere System Architecture (Updated)
## Flutter Frontend + Laravel Backend (PostgreSQL + Reverb WebSocket)

### Tech Stack
```
Frontend: Flutter (Dart) - Multiplatform (iOS/Android/Web)
├── Navigation: main.dart ViewType enum routing
├── State: SessionManager (SharedPreferences)
├── API: http package → ApiService singleton
├── Payments: Razorpay Native/Web
├── Real-time: WebSocketService (Reverb/Pusher protocol)
└── Config: app_config.dart (BACKEND_HOST dynamic)

Backend: Laravel 11 (PHP)
├── API: routes/api.php Sanctum auth + role middleware
├── DB: PostgreSQL ('pgsql' driver - confirmed in config/database.php)
├── Broadcasting: Reverb WebSocket (config/reverb.php, config/broadcasting.php)
│   ├── ws://host:9000/app/z7jb69t7onshtuge4biw (REVERB_APP_KEY)
│   ├── Private channels: private-vendor.{id} / private-customer.{id}
│   └── Events: order.placed, order.updated
├── Notifications: Queue-based (PayLaterRequested/Decision/Confirmed)
└── Payments: Razorpay PHP SDK verification

External:
├── Razorpay Gateway
├── Reverb WebSocket Server (Laravel 11 native)
├── PostgreSQL Database
└── Mail driver (config/mail.php)
```

### Architecture Layers
```
External Services
├── Razorpay Payments ──┐
├── Reverb WS (port 9000) ──┤
└── Email/SMS ───────────┘
          │
Flutter App (c:/Users/KIIT0001/front)
├── lib/main.dart (SPA routing)
├── lib/services/api_service.dart (REST)
├── lib/services/websocket_service.dart (Reverb private channels)
└── lib/pages/ (Customer/Vendor views)
          │ HTTP + WS
Laravel API (../Herd/sandbackend)
├── routes/api.php (endpoints)
├── app/Http/Controllers/Api/ (Auth/Payment/Order/Vendor)
├── app/Models/ (OrderItem key model)
├── app/Notifications/ (Queued emails)
└── config/ (database.php=pgsql, reverb.php, broadcasting.php)
          │ Eloquent
PostgreSQL DB
├── users (role=customer/vendor)
├── orders
├── order_items (status + payment_status)
├── addresses (lat/lng)
└── marketplace_listings (sand materials)
```

### Key Data Flows
```
1. Authentication
Flutter → POST /login (email/role) → Sanctum token → SharedPrefs → Home screen

2. Marketplace Browsing
Flutter → GET /marketplace → Listings → POST /cart → POST /orders/direct

3. Order Lifecycle
Pending → Vendor POST /vendor/orders/{id}/accept → accepted/unpaid
  ├─ Customer POST /pay-now → Razorpay verify → processing/paid → Stock deduct
  └─ Customer POST /pay-later → Vendor approves → processing/pay_later

4. Reverb WebSocket (confirmed implementation)
Flutter WebSocketService.connect(token, userId, isVendor):
  ws://host:9000/app/z7jb69t7onshtuge4biw
  → pusher:subscribe private-vendor.{id}
  → Events: order.placed, order.updated → onNotification callback → UI refresh

5. Notifications Flow
Laravel event → Queue → Email + DB mark read
Flutter GET /notifications → List unread
```

### Deployment Layout
```
c:/Users/KIIT0001/
├── front/ (Flutter)
│   ├── docs/ (this file + flowcharts)
│   ├── lib/services/websocket_service.dart (Reverb client)
│   └── pubspec.yaml
└── ../Herd/sandbackend/ (Laravel + Postgres)
    ├── config/database.php (pgsql driver)
    ├── config/reverb.php (host:0.0.0.0 port:8080 app_key:z7jb69*)
    ├── config/broadcasting.php (reverb driver primary)
    ├── nixpacks.toml (deployment)
    └── database/migrations/*.php (OrderItem schema)
```

### OrderItem Model (Core)
```
Fields:
- status: pending/accepted/processing/delivered/declined
- payment_status: unpaid/paid/pay_later  
- payment_due_at, days_requested
- subtotal + delivery_charge = total_amount
- listing_id → vendor materials
Relations: belongsTo Order, Vendor, Product
```

**Updated by BLACKBOXAI** - PostgreSQL + Laravel Reverb WebSocket confirmed via:
- config/database.php (pgsql driver)
- lib/services/websocket_service.dart (ws://:9000 Reverb app_key)
- config/reverb.php + broadcasting.php (reverb driver)

