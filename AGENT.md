# SawYunTech POS — Agent Reference Guide

This file is the single source of truth for building and maintaining the **Flutter mobile app** in parity with the **React web app**. Every screen, workflow, UI rule, and design token documented here is derived from the production web frontend. When adding or modifying any mobile feature, check this file first.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Role System & Access Control](#3-role-system--access-control)
4. [Design System](#4-design-system)
5. [Routes & Screens — Web vs Mobile](#5-routes--screens--web-vs-mobile)
6. [Feature Specifications by Area](#6-feature-specifications-by-area)
7. [Key Workflows](#7-key-workflows)
8. [API Endpoint Reference](#8-api-endpoint-reference)
9. [Mobile Implementation Rules](#9-mobile-implementation-rules)

---

## 1. Project Overview

SawYunTech POS is a multi-tenant SaaS point-of-sale platform. Businesses (tenants) subscribe to a plan and manage their POS operations. The platform is operated by a Super Admin and distributed through Resellers.

**Core entities:**
- **Tenant** — a business account (has branches, staff, products, customers)
- **Branch** — a physical store location under a tenant
- **User** — belongs to a tenant with a role (BUSINESS_OWNER, MANAGER, CASHIER, INVENTORY_STAFF)
- **Reseller** — an independent agent who signs up businesses and earns commissions
- **Super Admin** — platform operator with full access

---

## 2. Tech Stack

### Web (React)
- **Router:** React Router v6 (nested routes with layouts)
- **State:** Zustand + React Query (TanStack Query)
- **Styling:** Tailwind CSS (dark theme, zinc + amber palette)
- **Charts:** Recharts
- **Scanner:** html5-qrcode (camera), keyboard-event capture (USB/BT)
- **Print:** Browser print API with thermal templates (58mm/80mm)
- **Offline:** IndexedDB sync queue

### Mobile (Flutter)
- **Router:** GoRouter 14.x (ShellRoute + nested routes)
- **State:** Riverpod 2.x (StateNotifierProvider, FutureProvider.autoDispose)
- **HTTP:** Dio 5.x (singleton `apiClient.dio`)
- **Charts:** fl_chart
- **Scanner:** mobile_scanner (camera), keyboard event capture (USB/BT)
- **Print:** ESC/POS protocol via Bluetooth (flutter_blue_plus) + USB (usb_serial)
- **Offline:** SQLite (sqflite) sync queue
- **Images:** cached_network_image
- **Fonts:** Google Fonts — Outfit

---

## 3. Role System & Access Control

### User Roles

| Role | Value | Access |
|------|-------|--------|
| Super Admin | `SUPER_ADMIN` | Full platform — `/super-admin/*` |
| Reseller | `RESELLER` | Reseller portal — `/reseller/*` |
| Business Owner | `BUSINESS_OWNER` | Full tenant — `/app/*` |
| Manager | `MANAGER` | Full tenant (no billing) — `/app/*` |
| Cashier | `CASHIER` | POS + orders + customers (read) — `/app/*` |
| Inventory Staff | `INVENTORY_STAFF` | Products + inventory — `/app/*` |

### Permission Gates (web enforced, mobile must match)

| Action | Roles Allowed |
|--------|---------------|
| Create/edit/delete products | BUSINESS_OWNER, MANAGER, INVENTORY_STAFF |
| Create/edit customers | BUSINESS_OWNER, MANAGER, CASHIER |
| Process POS sales | BUSINESS_OWNER, MANAGER, CASHIER |
| View analytics | BUSINESS_OWNER, MANAGER |
| Manage staff (users) | BUSINESS_OWNER, MANAGER |
| Manage branches | BUSINESS_OWNER |
| Access billing/subscription | BUSINESS_OWNER |
| Procurement (POs, suppliers) | BUSINESS_OWNER, MANAGER, INVENTORY_STAFF |
| Stock adjustments | BUSINESS_OWNER, MANAGER, INVENTORY_STAFF |

### Subscription Gates
- **Trial expired / Subscription expired:** Transparent overlay blocks all `/app/*` routes except `/app/subscription/*`. Shows upgrade modal.
- **Analytics** is feature-gated per plan (entitlement check).
- **Product/User/Branch limits** are enforced at creation time with `402` or validation error.

---

## 4. Design System

### Colors (exact hex values — use these everywhere)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#09090B` | Scaffold/page background (zinc-950) |
| `surface` | `#18181B` | Cards, AppBar, BottomSheet (zinc-900) |
| `surfaceVariant` | `#27272A` | Inputs, chips, secondary containers (zinc-800) |
| `divider` | `#3F3F46` | Borders, dividers (zinc-700) |
| `border` | `#52525B` | Secondary borders (zinc-600) |
| `primary` | `#F59E0B` | Amber-500 — main brand, CTAs, highlights |
| `primaryDark` | `#D97706` | Amber-600 — gradient end |
| `primaryFg` | `#000000` | Text on amber backgrounds |
| `textPrimary` | `#FAFAFA` | Main text (zinc-50) |
| `textSecondary` | `#A1A1AA` | Labels, subtitles (zinc-400) |
| `textDisabled` | `#52525B` | Placeholder, disabled (zinc-600) |
| `success` | `#4ADE80` | Green-400 text |
| `successLight` | `#052E16` | Green-950 background |
| `error` | `#F87171` | Red-400 text |
| `errorLight` | `#450A0A` | Red-950 background |
| `warning` | `#FBBF24` | Amber-400 text |
| `warningLight` | `#451A03` | Amber-950 background |
| `info` | `#60A5FA` | Blue-400 text |
| `infoLight` | `#172554` | Blue-950 background |
| `secondary` | `#A78BFA` | Violet-400 (replacement refunds, etc.) |

### StatusBadge Colors (web `rounded-full` pill)

| Status values | Color |
|---------------|-------|
| ACTIVE, OPEN, COMPLETED, PAID, RECEIVED, APPROVED, IN_STOCK, SUCCESS | success (green) |
| ORDERED, PROCESSING, INFO, REVIEW | info (blue) |
| PENDING, DRAFT, PARTIAL, TRIAL, REFUNDED, LOW_STOCK, SUSPENDED | warning (amber) |
| INACTIVE, VOIDED, CANCELLED, EXPIRED, REJECTED, OUT_OF_STOCK, FAILED | error (red) |
| anything else | textSecondary on surfaceVariant |

**Shape:** Fully rounded pill (`BorderRadius.circular(100)`), border with `textColor.withValues(alpha: 0.35)`.

### Typography (Outfit font)

| Element | Size | Weight |
|---------|------|--------|
| Page title | 18–20px | w700 |
| Section header | 16px | w600 |
| Card title | 14–15px | w600 |
| Body text | 14px | w400 |
| Secondary text | 12px | w400 |
| Labels / chips | 11–12px | w500–w600 |
| KPI value | 20–24px | w700–w800 |
| Section label (ALL CAPS) | 11px | w700, letter-spacing 0.8 |

### Card Style (all cards must use this)
```
color: surface (#18181B)
borderRadius: circular(12)  — mobile uses 12px; web uses rounded-2xl (16px)
border: Border.all(color: divider)
padding: 14–16px
```

### Input Fields
```
filled: true
fillColor: surfaceVariant
border radius: 10px
enabledBorder: divider color
focusedBorder: primary (amber), width 1.5
labelStyle: textSecondary, 13–14px
```

### Buttons
| Variant | Background | Foreground |
|---------|-----------|------------|
| Primary | `primary (#F59E0B)` | `primaryFg (black)` |
| Danger | `error (#F87171)` or red-600 | white |
| Success | `success (#4ADE80)` or green-600 | white |
| Secondary/Outline | surfaceVariant | textPrimary |
| Ghost | transparent | textSecondary |

Min height: 44–48px for full-width buttons, 32px for inline actions.

### Empty State Pattern
Centered column, icon at opacity 0.3–0.4, title in textSecondary 14px w500, optional action button.

### Loading State
- Full page: `CircularProgressIndicator(color: AppColors.primary)` centered
- List shimmer: `ShimmerList` / `ShimmerGrid`
- Inline: small CircularProgressIndicator size 16–20px, strokeWidth 2

### AppBar Pattern
```
backgroundColor: surface
surfaceTintColor: transparent
bottom: PreferredSize 1px divider (height: 1, color: divider)
title: textPrimary, 18px, w700
iconTheme: textPrimary
```

### Filter Chips (horizontal scrollable row)
```
height: 36px
padding: horizontal 12, vertical 5
radius: circular(20) — pill
selected: primary fill, primaryFg text
unselected: surfaceVariant fill, textSecondary text
border: primary (selected) or divider (unselected)
```

---

## 5. Routes & Screens — Web vs Mobile

### Public / Auth Routes

| Web Route | Screen | Mobile Route | Status |
|-----------|--------|--------------|--------|
| `/login` | LoginPage (Owner+Staff tabs) | `/login` | ✅ |
| `/register` | RegisterPage | `/register` | ✅ |
| `/forgot-password` | ForgotPasswordPage | `/forgot-password` | ✅ |
| `/reset-password` | ResetPasswordPage | `/reset-password?token=` | ✅ |
| `/pricing` | PricingPage | `/pricing` | ✅ |
| `/onboarding` | OnboardingWizard | `/onboarding?tenantId=` | ✅ |
| `/trial-expired` | TrialExpiredPage | `/trial-expired` | ✅ |
| `/unauthorized` | UnauthorizedPage | (handled inline) | ✅ |

### App Routes — Tenant Users

| Web Route | Screen | Mobile Route | Status |
|-----------|--------|--------------|--------|
| `/app/dashboard` | BusinessDashboardPage (Owner/Mgr) or StaffDashboardPage | `/dashboard/manager` or `/dashboard/cashier` | ✅ |
| `/app/pos` | POSScreen | `/pos` | ✅ |
| `/app/session-open` | SessionOpenScreen | `/session/open` | ✅ |
| `/app/session-close` | SessionCloseScreen | `/session/close` | ✅ |
| `/app/profile` | ProfileSettingsPage | `/settings/profile` | ✅ |
| `/app/products` | ProductsScreen | `/products` | ✅ |
| `/app/brands` | BrandsPage | `/brands` | ✅ |
| `/app/categories` | CategoriesPage | `/categories` | ✅ |
| `/app/inventory` | InventoryScreen | `/inventory` | ✅ |
| `/app/sales` | SalesScreen | `/orders` | ✅ |
| `/app/customers` | CustomersScreen | `/customers` | ✅ |
| `/app/customers/new` | CustomerFormPage | `/customers` (FAB) | ✅ |
| `/app/customers/:id` | CustomerDetailPage | `/customers` → detail | ✅ |
| `/app/customers/:id/edit` | CustomerFormPage | customer detail → edit | ✅ |
| `/app/customers/:id/new-sale` | CustomerSaleFormPage | customer detail → new sale | ✅ |
| `/app/customers/:id/payments` | CustomerPaymentsPage | customer detail → payments | ✅ |
| `/app/customers/:id/statements` | CustomerStatementPage | customer detail → statement | ✅ |
| `/app/procurement/dashboard` | ProcurementDashboardPage | *(missing — see §6)* | ⚠️ |
| `/app/procurement/suppliers` | SuppliersPage | `/suppliers` | ✅ |
| `/app/procurement/suppliers/new` | SupplierFormPage | `/suppliers/new` | ✅ |
| `/app/procurement/suppliers/:id` | SupplierDetailPage | `/suppliers/:id` | ✅ |
| `/app/procurement/purchase-orders` | PurchaseOrdersPage | `/procurement` | ✅ |
| `/app/procurement/purchase-orders/new` | PurchaseOrderCreatePage | `/procurement/new` | ✅ |
| `/app/procurement/purchase-orders/:id` | PurchaseOrderDetailPage | `/procurement/:id` | ✅ |
| `/app/procurement/receipts/:id` | GoodsReceiptDetailPage | `/procurement/receipts/:id` | ✅ |
| `/app/procurement/payments` | SupplierPayablesPage | `/procurement/payables` | ✅ |
| `/app/analytics/dashboard` | AnalyticsDashboardPage | `/analytics` (tab 0) | ✅ |
| `/app/analytics/sales` | SalesAnalyticsPage | `/analytics` (tab 1) | ✅ |
| `/app/analytics/inventory` | InventoryAnalyticsPage | `/analytics` (tab 2) | ✅ |
| `/app/analytics/customers` | CustomerAnalyticsPage | `/analytics` (tab 3) | ✅ |
| `/app/analytics/financial` | FinancialAnalyticsPage | `/analytics` (tab 4) | ✅ |
| `/app/analytics/staff` | StaffAnalyticsPage | `/analytics` (tab 5) | ✅ |
| `/app/analytics/exports` | ExportsPage | `/analytics/export` | ✅ |
| `/app/notifications` | NotificationsPage | `/notifications` | ✅ |
| `/app/notifications/preferences` | NotificationPreferencesPage | `/notifications/preferences` | ✅ |
| `/app/notifications/:id` | NotificationDetailPage | notification tap | ✅ |
| `/app/subscription/current` | CurrentSubscriptionPage | `/subscription` (tab 0) | ✅ |
| `/app/subscription/plans` | SubscriptionPlansPage | `/subscription` (tab 0 plans) | ✅ |
| `/app/subscription/billing` | BillingHistoryPage | `/subscription` (tab 2) | ✅ |
| `/app/settings/business` | BusinessSettingsPage | `/settings/business` | ✅ |
| `/app/settings/branches` | BranchesSettingsPage | `/settings/branches` | ✅ |
| `/app/settings/staff` | StaffSettingsPage | `/users` | ✅ |
| `/app/settings/receipt` | ReceiptSettingsPage | `/settings/receipt` | ✅ |
| `/app/settings/tax` | TaxSettingsPage | `/settings/tax` | ✅ |
| `/app/settings/preferences` | PreferencesSettingsPage | `/settings/preferences` | ✅ |

### Super Admin Routes

| Web Route | Screen | Mobile Route | Status |
|-----------|--------|--------------|--------|
| `/super-admin/dashboard` | SuperAdminDashboardPage | `/dashboard/admin` | ✅ |
| `/super-admin/businesses` | BusinessesPage | `/admin/tenants` | ✅ |
| `/super-admin/businesses/:id` | BusinessDetailPage | `/admin/businesses/:id` | ✅ |
| `/super-admin/users/:id` | AdminUserDetailPage | `/admin/users/:id` | ✅ |
| `/super-admin/resellers` | ResellersPage | `/admin/resellers` | ✅ |
| `/super-admin/resellers/:id` | ResellerDetailPage | `/admin/resellers-detail/:id` | ✅ |
| `/super-admin/plans` | PlansPage | `/admin/plans` | ✅ |
| `/super-admin/plans/new` | PlanFormPage | `/admin/plans/new` | ✅ |
| `/super-admin/plans/:id` | PlanDetailPage | `/admin/plans/:id` | ✅ |
| `/super-admin/plans/:id/edit` | PlanFormPage | `/admin/plans/:id/edit` | ✅ |
| `/super-admin/notifications` | PlatformNotificationsPage | `/admin/notifications` | ✅ |
| `/super-admin/payment-methods` | PlatformPaymentMethodsPage | `/admin/payment-methods` | ✅ |
| `/super-admin/audit-logs` | AuditLogsPage | `/admin/audit` | ✅ |
| `/super-admin/reseller-finance` | ResellerFinancePage | `/admin/reseller-finance` | ✅ |

### Reseller Routes

| Web Route | Screen | Mobile Route | Status |
|-----------|--------|--------------|--------|
| `/reseller/dashboard` | ResellerDashboardPage | `/dashboard/reseller` | ✅ |
| `/reseller/businesses` | ResellerBusinessesPage | `/reseller/businesses` | ✅ |
| `/reseller/businesses/:id` | ResellerBusinessDetailPage | `/reseller/businesses/:id` | ✅ |
| `/reseller/analytics` | ResellerAnalyticsPage | `/reseller/analytics` | ✅ |
| `/reseller/customers` | ResellerCustomersPage | `/reseller/customers` | ✅ |
| `/reseller/inventory` | ResellerInventoryPage | `/reseller/inventory` | ✅ |
| `/reseller/procurement` | ResellerProcurementPage | `/reseller/procurement` | ✅ |
| `/reseller/subscriptions` | ResellerSubscriptionPage | `/reseller/businesses/:id/subscription` | ✅ |
| `/reseller/notifications` | ResellerNotificationsPage | `/reseller/notifications` | ✅ |
| `/reseller/notifications/:id` | NotificationDetailPage | notification tap | ✅ |
| `/reseller/profile` | ResellerProfilePage | `/reseller/profile` | ✅ |
| `/reseller/referrals` | ResellerReferralPage | `/reseller/referrals` | ✅ |
| `/reseller/plans` | ResellerPlansPage | `/reseller/plans` | ✅ |
| `/reseller/wallet` | ResellerWalletPage | `/reseller/wallet` | ✅ |

> ⚠️ **Procurement Dashboard** — web has `/app/procurement/dashboard` as a KPI overview screen with recent POs, receipts, and payables. Mobile jumps straight to the PO list. If adding in future, include: Ordered POs count, Partial Receipts, Open Payables, Awaiting Payment KPI cards + 3 recent-item lists.

---

## 6. Feature Specifications by Area

### 6.1 Authentication

**Login** — two modes:
1. Owner/Reseller/Admin: email + password
2. Staff: business code + phone/email + password (checkbox toggle)

Forgot password link → `/forgot-password`. Register link → `/register`.

**Register** — business owner self-signup (business name, email, password, optional phone).

**Onboarding Wizard** — triggered after first login for new business owners. Multi-step: business details → first branch → first product category. Guards all `/app/*` routes until complete. Check `tenant.onboarding_completed`.

**Trial Expired** — triggered when API returns `402`. Overlay/wall screen with upgrade CTA. Only `/subscription/*` routes are accessible.

---

### 6.2 Dashboard

#### Business Owner / Manager Dashboard
- **KPI cards:** Revenue Today, Revenue This Month, Inventory Value, Low Stock Count, Total Active Customers, Refunds Today, Pending POs, Outstanding Debt
- **Branch selector** (owner/manager): "All Branches" or per-branch — affects KPIs
- **Quick actions grid** (8 tiles): New Sale, Products, Orders, Inventory, Customers, Procurement, Analytics, Settings
- **Recent sales feed** (5 entries): order #, amount, time ago
- **Low stock alerts** (5 entries): product name, qty, reorder point
- **Pending POs** (5 entries): PO#, supplier, total

#### Cashier Dashboard
- Session status card (open/closed, opening balance, session duration)
- 4 quick actions: New Sale, Order History, Customers, Open/Close Session
- **New Sale** is disabled when session is closed — show "Open Session First" snackbar

#### Super Admin Dashboard
- KPI grid: Total Businesses, Total Users, Total Branches, Active Subscriptions, Trial Subscriptions, Expired Subscriptions
- 9 nav cards
- Live data from `GET /subscriptions/admin/overview`

#### Reseller Dashboard
- KPI cards: Total Clients, Wallet Balance (live from `GET /reseller/dashboard`)
- Quick nav: Dashboard (full), Wallet, My Clients, Commissions

---

### 6.3 POS / Checkout

**Layout:**
- Tablet (≥ 700dp / 720px): split panel — product grid (60%) + cart panel (40%) side by side
- Phone (< 700dp): full-screen product grid + floating "View Cart" FAB; cart is a bottom sheet or separate tab

**Product Grid:**
- Search bar (debounced, server-side)
- Category filter chips (horizontal scroll, "All" + per-category)
- Product cards: image thumbnail, name (2 lines), price
- Tap → add to cart (simple product) or variant picker bottom sheet (variable product)
- Barcode scanner button (camera) + USB/BT keyboard capture (always active)

**Cart Panel:**
- Line items: product name, qty (−/+), unit price, line total
- Long-press or swipe to remove item
- Discount row: flat amount or percentage, applies to subtotal
- Tax: shown as a line (from business tax settings)
- Total breakdown: subtotal → discount → tax → **TOTAL**
- Checkout button → Payment Dialog

**Payment Dialog / Overlay:**
- Payment methods: Cash, Card, Mobile Pay (KPay / WavePay / etc.)
- Multi-tender: can split across methods (e.g. partial cash + card)
- Cash: show "Change" calculation
- On success: receipt screen + "New Sale" button

**After sale:**
- Print receipt (thermal 58mm or 80mm based on settings)
- Option to attach to a customer account

**Offline mode:**
- Banner shown when no internet
- Sales queued in SQLite → synced when online
- Product lookup works offline from last sync

---

### 6.4 Products

**List screen:**
- Search (server-side)
- Category filter chips
- Each tile: image thumbnail, name, SKU, selling price, cost price, stock qty, ACTIVE/INACTIVE badge, PROMO badge (if discount active)
- Actions on tile: Edit (modal/screen), Print Label (printer service), Delete (with confirmation)
- FAB: Create product (role-gated: not CASHIER)

**Detail screen / side panel:**
- Full product info: name, description, category, brand, SKU, barcode, selling price, cost price
- Promotion: type, value, start/end dates, badge (Active / Scheduled / Expired)
- Variants table (if variable): variant name, attributes, price, stock
- Barcode + QR code display
- Print label button → select size (40×30 or 50×30)

**Form (Create / Edit):**
- Name*, SKU, description, category (dropdown), brand (dropdown)
- Selling price*, cost price
- Barcode field with scanner icon (opens camera scanner)
- Discount: type (flat/percent), value, start/end dates
- Active toggle
- Image upload

**Brands & Categories:**
- Simple list + CRUD (name, description, active toggle)
- Used as filter chips in Product list and POS grid

---

### 6.5 Inventory

**Stock Levels screen:**
- Branch selector
- Stat cards: Total Items, Out-of-Stock Count, Low Stock Count, Total Units
- Search by product name
- Filter: All / Low Stock / Out of Stock
- Sortable by stock level
- Each row: product name, SKU, qty, reorder point, status badge
- **Actions per row:**
  - **Adjust Stock** → modal: delta input (positive = add, negative = remove), reason dropdown (Purchase / Sale / Adjustment / Return / Damage / Expiry / Opening Stock), preview new qty
  - **History** → modal: paginated list of movements with type badges (color-coded), qty change, date, reference
- Auto-refreshes every 30 seconds (web), pull-to-refresh (mobile)

---

### 6.6 Orders / Sales

**Order list:**
- Tabs: Orders | Refunds
- Search by order number or customer name
- Status filter chips: All / Completed / Voided / Refunded
- Stat cards: Total Orders, Total Revenue, Avg Order Value
- Each tile: order #, customer name (or Guest), date, total, status badge
- Tap → detail side panel / screen

**Order detail:**
- Line items table: product, qty, unit price, line total
- Payment breakdown: method(s) used, amounts
- Summary: subtotal, discount, tax, total
- Actions:
  - **Reprint Receipt** → sends to printer
  - **Void Order** (if status = COMPLETED and within grace period) → confirmation dialog
  - **Refund** → opens refund dialog

**Refund dialog:**
- Select items + quantities to refund
- Refund type: Cash Refund or Replacement
- Reason text field
- On confirm: updates order status to REFUNDED, creates refund record

---

### 6.7 Customers

**List screen:**
- Search by name / phone / customer code
- Filter: Active / Inactive
- Stat cards: Total Customers, Active, With Balance, Total Outstanding Debt
- Each tile: name, phone, customer code, outstanding balance (amber)
- FAB: Create customer (role-gated: not INVENTORY_STAFF)

**Detail screen (tabbed or nested routes):**
- **Info tab:** name, phone, email, address, notes, member since, last order date
- **Stats:** Outstanding Debt, Orders This Month, Orders This Year
- **Recent Activity:** last 5 ledger entries
- **Actions:** Edit, New Sale (credit sale), View Full Ledger, Payments, Statement

**Customer Ledger:**
- All transactions for customer: sales, payments, adjustments
- Each entry: date, type, reference, debit, credit, balance

**Customer Payments:**
- Record a payment against outstanding balance
- Amount, date, payment method, notes
- Updates balance immediately

**Customer Statement:**
- Date-range filtered statement
- Opening balance → transactions → closing balance
- Exportable

**Customer Sale Form:**
- Creates a credit sale (order) linked to the customer
- Products added, quantities, prices
- Generates a debt entry on customer ledger

---

### 6.8 Procurement

**Procurement Dashboard (web only — not yet in mobile):**
- KPI cards: Ordered POs, Partial Receipts, Open Payables, Awaiting Payment
- Recent Purchase Orders table (5 rows)
- Recent Goods Receipts table (5 rows)
- Outstanding Payables table (5 rows)

**Suppliers:**
- List: name, contact, email, phone, outstanding payable amount
- Search
- Create / Edit / Delete supplier
- Supplier detail: info + related POs + payable history

**Purchase Orders:**
- List with status filter chips: All / DRAFT / ORDERED / PARTIAL / RECEIVED / CANCELLED
- Search by PO number or supplier
- Create PO: select supplier, add line items (product, qty, unit cost), set order date, expected delivery date, notes
- PO Detail:
  - Header: PO number, supplier, status badge
  - Order Info: dates, total
  - Line items: product, ordered qty, received qty (color-coded), line total
  - Notes section
  - **Actions:**
    - `ORDERED` → "Receive Goods" → creates Goods Receipt
    - `ORDERED` → "Cancel Order" → confirmation with optional reason
    - `ORDERED | PARTIAL | RECEIVED` → "View Goods Receipts" → list of GRNs for this PO

**Goods Receipts (GRN):**
- List filtered by PO (via `?poId=`)
- Detail: GRN number, PO reference, received date, line items with received quantities
- **Confirm GRN** action (if status = PENDING) → marks as confirmed, updates stock levels

**Supplier Payables:**
- List with status filter: All / OUTSTANDING / PARTIALLY_PAID / PAID
- Each row: supplier, PO reference, amount, paid, outstanding, due date, status
- **Record Payment** → amount, date, payment method, reference number
- Updates payable status and supplier balance

---

### 6.9 Analytics

All analytics are gated by plan entitlement. Date range filter applies across all tabs: Today / Last 7 Days / Last 30 Days / Last 90 Days.

**Overview tab:**
- KPI cards: Revenue, Orders, Avg Order Value, Active Customers
- Revenue trend line chart (daily granularity)
- Top 10 Products by revenue (bar chart)

**Sales tab:**
- Daily sales bar chart
- Top 10 Products table: rank, name, qty sold, revenue

**Inventory tab:**
- KPI cards: Total SKUs, Low Stock count, Out of Stock count, Total Inventory Value
- Low stock products list

**Customers tab:**
- KPI cards: Total Customers, New This Period, Returning Rate %
- Top 5 Customers by spend

**Financial tab:**
- KPI cards: Gross Revenue, Total Costs (COGS), Gross Profit, Profit Margin %
- Revenue vs Cost trend

**Staff tab:**
- Per-cashier table: cashier name, orders count, total sales
- Summary chips at top

**Export (9 types):**
1. Orders (date range)
2. Sales + Refunds
3. Top Products
4. Sales by Category
5. Sales by Cashier
6. Inventory Stocks
7. Low Stock Report
8. Payment Methods breakdown
9. Profit Report

Each downloads as CSV/Excel. Web uses `xlsx` library. Mobile uses the `/analytics/export/*` endpoints and opens/saves the file.

---

### 6.10 Notifications

**Notification Center:**
- Tabs: All / Unread
- Type filter chips: System, Inventory, Procurement, Customer, Subscription, Security
- Each tile: icon (by type), title, body preview, time ago, unread dot
- **Mark All Read** button
- Link to Preferences
- Auto-poll: every 60s (all), every 30s (unread count badge)
- Unread count badge in sidebar/AppBar

**Notification Detail:**
- Full content rendered
- Auto-marks as read on open

**Preferences:**
- Toggle groups: SALES (order alerts, daily summary), INVENTORY (low stock, out of stock), PROCUREMENT (procurement alerts), CUSTOMERS (customer alerts), SYSTEM (subscription renewal, security alerts)
- Auto-saves on toggle change

**Notification types mapping:**
```
type → icon
ORDER_COMPLETED → receipt_long
LOW_STOCK → warning_amber
PURCHASE_ORDER → shopping_cart
CUSTOMER_PAYMENT → payments
SUBSCRIPTION_RENEWAL → credit_card
SECURITY_ALERT → security
SYSTEM → notifications
```

---

### 6.11 Subscriptions & Billing

**Current Subscription tab:**
- Plan card: name, status badge, price/cycle, started date, expires date, auto-renew toggle
- Usage bars per feature: products, users, branches, customers, devices, analytics
  - Progress bar color: green (< 70%), amber (70–90%), red (> 90%)
- Available plans list (for upgrade/downgrade)
- **Actions:**
  - Upgrade/Downgrade → plan selection modal → confirm
  - Renew → upload payment proof sheet

**Payment Proofs tab:**
- Submit proof: image upload (JPG/PNG/PDF), amount, reference number
- Each proof card: date, amount, status badge (PENDING / APPROVED / REJECTED), review notes if rejected
- PENDING proofs show "under review" state

**Billing History tab:**
- Records: description, date, amount, currency, status badge
- Download icon → opens `invoice_url` or `receipt_url` in browser

---

### 6.12 Settings

**Business Settings:**
- Business name, email, phone, address, city, country
- Timezone (dropdown), Currency (dropdown — locked to MMK for most), Language
- Time format: 12h / 24h toggle
- Staff business code (read-only, with copy button)
- Account info: slug, status, plan (read-only)
- Save button (owner-only can edit)

**Branches:**
- List of branches for the tenant
- Create, Edit (name, address, phone, timezone, active toggle)
- Activate / Deactivate toggle

**Staff (Users):**
- Search by name/email
- Role filter chips: All / Cashier / Manager / Inventory
- Create: first name, last name, email, phone, role, password
- Edit: name, phone, role
- Activate / Deactivate

**Receipt Settings:**
- Header text, footer text
- Show/hide: logo, business name, address, phone, tax number
- Paper size: 58mm / 80mm

**Tax Settings:**
- Tax name, rate (%), type (Inclusive / Exclusive), active toggle

**Preferences:**
- Currency display format
- Date format
- Low stock threshold (default qty)

**Profile Settings:**
- Edit first name, last name, phone
- Change password: current + new + confirm

---

### 6.13 Super Admin Portal

**Businesses (Tenants):**
- Search by name/email/code
- Status filter: All / ACTIVE / TRIAL / EXPIRED / SUSPENDED
- Each card: name, initial avatar, business code, email, user count, branch count, status badge, created date
- Tap → Business Detail

**Business Detail:**
- Full tenant info: name, slug, email, phone, address
- Subscription card: plan, status, trial/expiry dates
- Branches list
- Staff list
- Devices list
- **Actions:** Suspend / Reactivate (with confirmation), Manage Subscription (override plan, set expiry), Impersonate (web only)

**Platform Users:**
- Search by name/email
- Role filter chips
- Each tile: avatar, name, email, role badge, status badge
- Tap → User Detail

**User Detail:**
- Profile info, role, status
- Tenant association
- Actions: Activate/Deactivate, Reset Password (sends email), Edit

**Resellers:**
- List: name, email, client count, wallet balance, commission rate, status badge
- FAB: Create Reseller (first name, last name, email, phone, password)
- Tap → Reseller Detail

**Reseller Detail:**
- Profile info, commission rate, wallet balance
- Assigned businesses list
- Commission history
- Actions: Adjust Commission Rate, Suspend/Activate

**Plans (Subscription Plans):**
- List: name, description, price/month, max users/branches/products, active badge
- FAB: Create Plan
- Plan Form: name, description, price, billing_cycle (MONTHLY/YEARLY), trial_days, entitlements (max_products, max_users, max_branches, max_customers, max_devices, analytics_enabled, etc.), active toggle
- Plan Detail: full entitlements display

**Admin Subscriptions:**
- List with status filter chips: All / TRIAL / ACTIVE / EXPIRED / SUSPENDED / CANCELLED
- Each card: tenant name + avatar, plan name, status badge
- **Pending Proof highlight:** amber border when `pending_proof_id` present
- **Approve / Reject** buttons on cards with pending proofs
- API: `POST /subscriptions/payment-proofs/{proofId}/review` with `{action: "approve"|"reject"}`

**Audit Logs:**
- Entity Type filter chips: All / USER / PRODUCT / ORDER / CUSTOMER / SUBSCRIPTION / TENANT / PAYMENT
- Action filter chips: All / CREATE / UPDATE / DELETE / LOGIN / APPROVE / CANCEL
- Each entry: action (bold) + entity type, user email, time ago
- Infinite scroll (30 per page)

**Devices:**
- List: platform (ANDROID/IOS/WEB), device name, device identifier, tenant name, last seen date
- Status badge
- (Web: revoke/deactivate device — mobile: read-only currently)

**Platform Notifications:**
- Broadcast a notification to: ALL tenants / specific tenant / specific role
- Title, body, type, priority
- Sent notifications history

**Payment Methods:**
- Platform-level payment methods: KPay, WavePay, Bank Transfer, etc.
- CRUD: name, code, instructions, active toggle

**Reseller Finance:**
- Reseller wallet overview: available balance, locked, total paid out
- Payout request queue: approve/reject
- Commission ledger

---

### 6.14 Reseller Portal

**Dashboard** (live from `GET /reseller/dashboard`):
- KPI cards: Total Clients, Active Clients, Total Commissions Earned, Wallet Balance
- Quick nav: Full Dashboard, Wallet, My Clients, Commissions

**Wallet** (from `GET /reseller/wallet`):
- Balance cards: Available, Total Earned, Total Paid Out
- **Request Payout** button → amount input (max = available balance), submits to `POST /reseller/request-payout`
- Transaction history: credit/debit, color-coded

**Referrals / My Clients:**
- List of businesses signed up through this reseller
- Referral code display + share link
- Conversion tracking: total referred, in trial, converted, conversion rate %

**Commissions:**
- Commission history entries: date, tenant, plan, amount, status

**My Businesses (Cross-business views):**
- Reseller can view analytics, customers, inventory, procurement across all their client businesses
- Uses reseller-scoped API endpoints

---

## 7. Key Workflows

### 7.1 First Login Flow (New Business Owner)
1. Register → email + business name + password
2. Login → redirected to `/onboarding`
3. Onboarding wizard: business details → branch → categories → complete
4. `tenant.onboarding_completed = true` → redirected to `/app/dashboard`
5. Trial period starts (14 days default)

### 7.2 POS Checkout Flow
1. Open cashier session (entering balance) → session stored server-side
2. Navigate to POS
3. Add items (search / barcode / category browse)
4. Apply discount (optional)
5. Tap Checkout → Payment Dialog
6. Select payment method(s), enter amounts
7. Confirm → `POST /sales/checkout`
8. Success → receipt screen
9. Print receipt (optional)
10. "New Sale" → clear cart, stay on POS

### 7.3 Stock Adjustment Flow
1. Inventory screen → find product row
2. Tap Adjust → bottom sheet
3. Enter delta quantity (positive = add, negative = remove)
4. Select reason from dropdown
5. Preview new quantity
6. Confirm → `POST /inventory/adjustments`
7. Row updates immediately

### 7.4 Purchase Order → Goods Receipt Flow
1. Create PO → status = DRAFT
2. "Submit" PO → status = ORDERED
3. Supplier delivers → "Receive Goods" on PO detail
4. Create GRN: enter received quantities per line item
5. GRN status = PENDING
6. "Confirm" GRN → status = CONFIRMED, stock levels updated
7. PO status → PARTIAL (if some items short) or RECEIVED (all received)
8. A Payable is created for the supplier

### 7.5 Subscription Renewal Flow (Tenant)
1. Subscription expires → `402` response on any API call
2. App redirects to `/trial-expired` (mobile) or shows overlay (web)
3. User taps "Upgrade" → goes to `/subscription`
4. Selects plan → "Renew" button
5. Upload payment proof (image + amount + reference)
6. Status = PENDING → "Under Review" message
7. Super Admin reviews → Approve or Reject
8. On Approve → subscription activated, `402` stops

### 7.6 Customer Credit Sale Flow
1. Navigate to Customer Detail
2. Tap "New Sale"
3. Add products and quantities
4. Submit → creates Order with CREDIT payment method
5. Ledger entry created (debit on customer)
6. Outstanding balance increases
7. Customer can pay later via "Record Payment"

### 7.7 Reseller Commission Flow
1. Reseller shares referral code / link
2. New tenant registers with reseller's code
3. Tenant subscribes to a plan
4. Commission calculated (% of subscription value)
5. Commission entry added to reseller's wallet (LOCKED)
6. After cooldown period → becomes AVAILABLE
7. Reseller requests payout → Super Admin approves → PAID OUT

---

## 8. API Endpoint Reference

### Auth
| Method | Endpoint | Usage |
|--------|----------|-------|
| POST | `/auth/login` | Login |
| POST | `/auth/refresh` | Refresh access token (cookie) |
| POST | `/auth/logout` | Logout |
| GET | `/auth/me` | Current user |
| POST | `/auth/change-password` | Change password |
| POST | `/auth/register` | Register new business |
| POST | `/auth/forgot-password` | Send reset email |
| POST | `/auth/reset-password` | Reset password with token |

### Products
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/products` | List (search, category_id, brand_id, is_active, page, page_size) |
| POST | `/products` | Create |
| GET | `/products/:id` | Detail |
| PUT | `/products/:id` | Update |
| DELETE | `/products/:id` | Delete |
| GET | `/products/:id/variants` | Variants list |
| GET | `/categories` | List categories |
| POST | `/categories` | Create category |
| GET | `/brands` | List brands |
| POST | `/brands` | Create brand |

### Inventory
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/inventory/stock-levels` | Stock levels (branch_id, search, page) |
| POST | `/inventory/adjustments` | Adjust stock |
| GET | `/inventory/movements` | Movement history (product_id, branch_id) |

### POS / Sales
| Method | Endpoint | Usage |
|--------|----------|-------|
| POST | `/cashier-sessions` | Open session |
| POST | `/cashier-sessions/:id/close` | Close session |
| POST | `/sales/carts` | Create cart |
| GET/PATCH | `/sales/carts/:id` | Cart operations |
| POST | `/sales/checkout` | Complete checkout |
| GET | `/sales/orders` | Order list |
| GET | `/sales/orders/:id` | Order detail |
| POST | `/sales/orders/:id/void` | Void order |
| POST | `/payments/:orderId/refund` | Refund |

### Customers
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/customers` | List (search, is_active, page) |
| POST | `/customers` | Create |
| GET | `/customers/:id` | Detail |
| PUT | `/customers/:id` | Update |
| GET | `/customers/:id/ledger` | Ledger entries |
| POST | `/customers/:id/payments` | Record payment |

### Procurement
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/suppliers` | List suppliers |
| POST | `/suppliers` | Create |
| PUT | `/suppliers/:id` | Update |
| DELETE | `/suppliers/:id` | Delete |
| GET | `/procurement/purchase-orders` | List POs (status, supplier_id) |
| POST | `/procurement/purchase-orders` | Create PO |
| GET | `/procurement/purchase-orders/:id` | PO detail |
| POST | `/procurement/purchase-orders/:id/cancel` | Cancel PO |
| POST | `/procurement/purchase-orders/:id/items` | Add line item |
| GET | `/procurement/receipts` | List GRNs |
| POST | `/procurement/receipts` | Create GRN |
| GET | `/procurement/receipts/:id` | GRN detail |
| POST | `/procurement/receipts/:id/confirm` | Confirm GRN |
| GET | `/procurement/payables` | List payables |
| POST | `/procurement/payables/:id/payments` | Record payable payment |

### Analytics
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/analytics/dashboard` | Overview KPIs |
| GET | `/analytics/sales/summary` | Sales summary (period) |
| GET | `/analytics/sales/top-products` | Top products |
| GET | `/analytics/inventory/summary` | Inventory KPIs |
| GET | `/analytics/customers/summary` | Customer KPIs |
| GET | `/analytics/financial/summary` | Financial KPIs |
| GET | `/analytics/staff/summary` | Staff performance |
| GET | `/analytics/export/*` | Export endpoints (9 types) |

### Notifications
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/notifications` | List (is_read, type, page) |
| GET | `/notifications/unread-count` | Unread badge count |
| POST | `/notifications/:id/read` | Mark read |
| POST | `/notifications/read-all` | Mark all read |
| GET/PUT | `/notifications/preferences` | Get/update preferences |

### Subscriptions
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/subscriptions/plans` | Public plan list |
| GET | `/subscriptions/status` | Current subscription |
| POST | `/subscriptions/payment-proofs/upload` | Upload proof |
| GET | `/subscriptions/payment-proofs` | My proof history |
| GET | `/subscriptions/admin/overview` | Admin KPIs |
| GET | `/admin/subscriptions` | Admin sub list |
| POST | `/subscriptions/payment-proofs/:id/review` | Approve/Reject proof |

### Admin
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/tenants` | Business list (search, status, page) |
| GET | `/users` | Platform users (search, role, page) |
| GET | `/resellers` | Reseller list |
| GET | `/audit` | Audit logs (entity_type, action, page) |
| GET | `/devices` | Device list |
| POST | `/admin/notifications` | Broadcast notification |

### Reseller
| Method | Endpoint | Usage |
|--------|----------|-------|
| GET | `/reseller/dashboard` | Reseller KPIs |
| GET | `/reseller/wallet` | Wallet detail |
| POST | `/reseller/request-payout` | Request payout |
| GET | `/reseller/commissions` | Commission history |
| GET | `/reseller/referrals` | Referral list |
| GET | `/resellers/me/businesses` | My client businesses |

---

## 9. Mobile Implementation Rules

### State Management
- **Screen-scoped providers:** Use `FutureProvider.autoDispose` for lightweight data loaded once per screen (categories, brands, plan list).
- **List screens with search/filter:** Use `StateNotifierProvider` with search/filter fields in state. `setSearch()` / `setFilter()` methods reset page to 1 and call `load(refresh: true)`.
- **Never hardcode data** — all KPI values, lists, and status counts must come from live API calls.

### Navigation
- Use GoRouter `context.push()` for forward navigation, `context.pop()` for back.
- After create/edit in a bottom sheet, call `onCreated()` callback to refresh the parent list.
- Routes ending in `?poId=` or `?tenantId=` pass IDs as query params; read with `GoRouterState.uri.queryParameters`.

### API Calls
- All calls go through `apiClient.dio` singleton.
- `Dio get _dio => apiClient.dio;` in every repository.
- `AppException.fromDio(e)` for user-facing error messages.
- Never catch and swallow errors silently — always surface to the user via SnackBar.

### Deprecated Flutter APIs — NEVER USE
| Deprecated | Use instead |
|-----------|-------------|
| `DropdownButtonFormField(value: ...)` | `DropdownButtonFormField(initialValue: ...)` |
| `color.withOpacity(0.x)` | `color.withValues(alpha: 0.x)` |
| `Switch(activeColor: ...)` | `Switch(activeThumbColor: ..., activeTrackColor: ...)` |
| `MediaQuery.of(ctx).viewInsets` | `MediaQuery.viewInsetsOf(ctx)` |

### Sentinel Pattern for nullable copyWith
When a state field is nullable and `copyWith` needs to clear it:
```dart
const _sentinel = Object();
// In copyWith:
Object? statusFilter = _sentinel,
// In body:
statusFilter: statusFilter == _sentinel ? this.statusFilter : statusFilter as String?,
```

### Null Safety in Conditions
- `invoiceUrl != null` makes `invoiceUrl` non-nullable in the `if` branch — don't use `?? ''` or `!` inside.
- `Uri.tryParse(invoiceUrl)` not `Uri.tryParse(invoiceUrl!)`.

### Images
- Always use `CachedNetworkImage` for remote images, never `Image.network`.
- Provide a placeholder and errorWidget showing the relevant icon.
- Product tiles: 48×48px, `BorderRadius.circular(8)`.

### Printer Integration
- Printer service is a global singleton `printerService`.
- Print operations: `printerService.printReceipt(order)` / `printerService.printLabel(product)`.
- Always handle the `false` return (no printer connected) with a SnackBar.

### Role Checks
```dart
// From auth provider:
final user = ref.watch(currentUserProvider);
final canCreate = user?.canManageProducts ?? false;
// Role check:
user?.role == UserRole.superAdmin
user?.role == UserRole.businessOwner
user?.role == UserRole.manager
user?.role == UserRole.cashier
user?.role == UserRole.inventoryStaff
user?.role == UserRole.reseller
```

### Error Display
- API errors → `SnackBar` with `AppColors.error` background, `SnackBarBehavior.floating`.
- Success → `SnackBar` with `AppColors.success` background.
- Full-page errors → `ErrorView(message: ..., onRetry: ...)`.
- Empty states → `EmptyView(icon: ..., title: ...)`.

### Bottom Sheet Pattern
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,   // required for keyboard-aware sheets
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    ...
  ),
);
```

### Confirmation Dialog Pattern
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text('...', style: TextStyle(color: AppColors.textPrimary)),
    content: Text('...', style: TextStyle(color: AppColors.textSecondary)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
        onPressed: () => Navigator.pop(ctx, true),
        child: Text('Confirm'),
      ),
    ],
  ),
);
if (confirmed != true || !mounted) return;
```
