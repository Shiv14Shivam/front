graph TD
    A[Flutter App<br/>main.dart ViewType Routing] --> B[ApiService<br/>HTTP to /api]
    B --> C[Laravel Backend<br/>routes/api.php]
    C --> D[Controllers<br/>Auth/Order/Payment/Vendor]
    D --> E[DB: Users/Orders/OrderItems/Addresses/Listings]
    C --> F[Pusher WebSocket<br/>vendor.{id}/customer.{id}]
    F --> A
    D --> G[Notifications<br/>PayLaterRequested/Decision/Confirmed]
    G --> A
    H[Razorpay Gateway] <--> B
    I[Email/SMS] <--> G



flowchart TD
    Start((Landing)) --> Login[Login<br/>POST /login]
    Login --> HomeC{Customer Home}
    HomeC --> Browse[Marketplace<br/>GET /marketplace]
    Browse --> Cart[Add to Cart<br/>POST /cart]
    Cart --> Checkout[Request Order<br/>POST /orders/direct<br/>or /from-cart]
    Checkout --> VendorReview[Vendor sees<br/>GET /vendor/orders]
    VendorReview --> AcceptV[Vendor Accept<br/>POST /vendor/orders/{id}/accept]
    AcceptV --> PayOptions{Pay Now<br/>or Pay Later?}
    PayOptions -->|Now| Razorpay[POST /pay-now<br/>Verify Razorpay]
    Razorpay --> Paid[Status: processing/paid<br/>Stock deduct]
    PayOptions -->|Later| PayLaterReq[POST /pay-later<br/>days_requested=3]
    PayLaterReq --> VendorDecide{Vendor Approve?}
    VendorDecide -->|Yes| ApprovePL[POST /pay-later/accept<br/>Status: processing/pay_later]
    VendorDecide -->|No| RejectPL[POST /pay-later/reject<br/>Status: declined]
    ApprovePL --> PayLaterDue[Pay by due date<br/>or Overdue]
    PayLaterDue --> Razorpay
    RejectPL --> Reorder[Back to Pay Now]
    Paid --> NotifyC[PaymentConfirmed Notif]
    NotifyC --> Track[Notifications<br/>GET /notifications]
    Track --> End((Delivered))

flowchart TD
    StartV((Vendor Login)) --> DashboardV[Vendor Home<br/>GET /vendor/dashboard]
    DashboardV --> Inventory[Manage Inventory<br/>GET/PATCH /vendor/inventory]
    Inventory --> Listing[Create Listing<br/>POST /seller/listings]
    Listing --> Marketplace[Public: GET /marketplace]
    Marketplace --> CustomerOrder[Customer Orders]
    CustomerOrder --> PendingOrders[GET /vendor/orders<br/>Status: pending]
    PendingOrders --> ActionV{Accept/Decline?}
    ActionV -->|Accept| AcceptO[POST /accept<br/>Status: accepted/unpaid]
    ActionV -->|Decline| DeclineO[POST /decline<br/>Status: declined]
    AcceptO --> PayWait[Customer Payment]
    PayWait --> PayNowC[Customer Pay Now]
    PayNowC --> Processing[Status: processing/paid<br/>Stock -= qty]
    PayWait --> PayLaterR[Customer Pay Later Req]
    PayLaterR --> PLDecision{Approve Later?}
    PLDecision -->|Approve| AcceptPL[POST /pay-later/accept<br/>Status: processing/pay_later]
    PLDecision -->|Reject| RejectPL[POST /pay-later/reject<br/>Status: declined]
    AcceptPL --> LaterDue[Customer pays later]
    LaterDue --> Processing
    Processing --> NotifyV[PaymentConfirmed]
    NotifyV --> DashboardV



sequenceDiagram
    participant C as Customer App
    participant API as Laravel API
    participant DB as Database
    participant V as Vendor
    participant R as Razorpay
    participant WS as WebSocket/Pusher

    C->>API: POST /orders/direct {listing_id, qty, address_id}
    API->>DB: Create OrderItem status=pending payment_status=unpaid
    V->>API: POST /vendor/orders/{id}/accept
    API->>DB: status=accepted payment_status=unpaid
    WS->>C: Order Accepted

    alt Pay Now
        C->>R: Create Razorpay Order
        R->>C: payment_id
        C->>API: POST /orders/{id}/pay-now {razorpay_payment_id}
        API->>R: Verify payment
        API->>DB: status=processing payment_status=paid<br/>Stock deduct
        API->>C: Success
        WS->>V: Payment Confirmed
    else Pay Later
        C->>API: POST /orders/{id}/pay-later {days_requested=3}
        API->>DB: payment_status=pay_later due_at=+3days
        WS->>V: PayLaterRequested
        V->>API: POST /pay-later/{id}/accept
        API->>DB: status=processing<br/>Stock deduct
        WS->>C: PayLaterDecision approved
        Note over C,V: Customer pays later via Razorpay<br/>before due date
    end

    API->>C: PaymentConfirmedNotification
    API->>V: PaymentConfirmedNotification



Status Flow:
pending ──(vendor accept)──> accepted/unpaid ──(pay now)──> processing/paid ──> delivered/paid
                    │
                    └─(pay later req)──> accepted/pay_later ──(vendor approve)──> processing/pay_later ──(pay)──> delivered/paid
                                        │
                                        └─(vendor reject)──> declined/unpaid



| Role | Endpoint | Method | Purpose |
|------|----------|--------|---------|
| Public | `/marketplace` | GET | Browse listings |
| Auth | `/login`, `/register` | POST | Auth |
| Customer | `/orders/direct`, `/cart` | POST | Order/cart |
| Customer | `/orders/{id}/pay-now` | POST | Razorpay confirm |
| Customer | `/orders/{id}/pay-later` | POST | Request credit |
| Vendor | `/vendor/orders/{id}/accept` | POST | Accept order |
| Vendor | `/orders/{id}/pay-later/accept` | POST | Approve credit |
| All | `/notifications` | GET | Inbox |
