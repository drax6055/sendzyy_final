# Sendzyy Super Admin Integration & Backend API Specification

This document provides a comprehensive technical implementation plan and API specification for integrating the **React Super Admin Dashboard** with the **Sendzyy Backend Node.js/Express Server**.

---

## 1. Architectural Principles & Isolation Strategy

To ensure that the Super Admin functionality is integrated smoothly **without impacting any existing tenant features, mobile app APIs, or campaign processing**:

1. **API Namespacing**: All Super Admin endpoints are isolated under the route prefix `/api/superadmin/*`.
2. **Dedicated Middleware (`authenticateSuperAdmin`)**: Super Admin requests use JWT authentication verified with `role: 'superadmin'`. Existing tenant routes (`/api/clients`, `/api/campaigns`, etc.) remain completely untouched.
3. **Database Integrity**:
   - Uses existing MongoDB schemas (`Tenant`, `PanelPackage`, `PaymentRecord`) with zero breaking changes to existing fields.
   - Preserves tenant authentication and subscription enforcement in `server.js`.

---

## 2. Super Admin Core Features & Workflow Specifications

### A. Tenant Registration Workflow (Payment Clearance Enforcement)

#### Business Rule:
> *If payment is not cleared, DO NOT store the tenant in the database, rendering them unable to log in.*

#### Technical Implementation:
Sendzyy operates on a **Payment-First Staging Architecture**:
1. **Self-Service / Online Registration**:
   - Step 1: Registration details are validated and saved in a temporary, short-lived JWT registration token (staged in memory/token). **No record is inserted into MongoDB yet.**
   - Step 2: Tenant initiates payment via Razorpay.
   - Step 3: `POST /verify-panel-payment` validates the payment signature. **ONLY AFTER successful payment verification** is `Tenant.create(...)` called to store the tenant in MongoDB (`status: 'active'`).
   - If payment fails, is abandoned, or fails verification, the DB write is never performed. The user cannot log in because `Tenant.findOne({ email })` will return `null`.

2. **Super Admin Registration Capabilities**:
   The React Super Admin portal will support two registration modes:

   * **Mode 1: Manual / Direct Super Admin Registration (Paid / Comped / Offline Clearance)**
     - **Endpoint**: `POST /api/superadmin/tenants/register-manual`
     - **Use Case**: Super Admin registers a tenant who paid via Cash/Bank Transfer or received a comped plan.
     - **Logic**: Payment clearance is confirmed by Super Admin -> Creates `Tenant` in MongoDB with `status: 'active'` -> Generates `PaymentRecord` -> Sends welcome credentials email.

   * **Mode 2: Payment Invite Registration (Online Clearance - LIVE RAZORPAY API)**
     - **Endpoint**: `POST /api/superadmin/tenants/create-payment-invite`
     - **Use Case**: Super Admin initiates onboarding for a tenant who will pay online via Razorpay (real transaction).
     - **Razorpay Live Integration**: Uses the **Live Razorpay API Keys** (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`) since Mode 1 already covers cash/bank/offline payments. Order generation and signature verification use the same live production credentials as standard self-service registration.
     - **Logic**: Sends a payment link email containing a pre-configured registration token (72-hour expiry). The tenant completes real payment via Razorpay. Only upon successful live payment verification does the server write the `Tenant` document to MongoDB (`status: 'active'`).

---

### B. Package Management (Create, Edit, Delete/Deactivate)

#### Existing Schema (`PanelPackage`):
```json
{
  "planId": "panel_12m",
  "name": "12 Month Access",
  "description": "12 months full panel access",
  "basePrice": 12711,
  "gstPercent": 18,
  "totalPrice": 14999,
  "panelDays": 365,
  "isActive": true
}
```

#### Operations:
- **CREATE**: `POST /api/superadmin/packages` — Adds a new package to `PanelPackage` collection.
- **EDIT**: `PUT /api/superadmin/packages/:id` — Updates pricing, duration, description, or package name.
- **DELETE / DEACTIVATE**: `DELETE /api/superadmin/packages/:id` — Performs a soft-delete by setting `isActive: false` (or hard deletes if no active tenant subscriptions reference `planId`). Soft delete prevents breaking historical payment logs.
- **LIST ALL**: `GET /api/superadmin/packages` — Returns all active and inactive packages for Super Admin management.

---

### C. Tenant Management (List All & Active/Inactive Control)

#### Features:
1. **List All Tenants**: `GET /api/superadmin/tenants`
   - Supports search (name, email), status filtering (`active`, `inactive`, `expired`), pagination (`page`, `limit`), and sort options.
   - Includes real-time subscription details (`expiryDate`, `daysRemaining`) and WhatsApp onboarding status.
2. **Tenant Status Toggle**: `PATCH /api/superadmin/tenants/:id/status`
   - Updates `Tenant.status` to `'active'` or `'inactive'`.
   - **Login Block Enforcement**: Existing `/login` endpoint in `server.js` already blocks inactive users:
     ```javascript
     if (tenant.status === 'inactive') {
         return res.status(403).json({
             error: 'account_inactive',
             message: 'Your account is inactive. Please contact support.'
         });
     }
     ```
     When Super Admin sets status to `'inactive'`, the tenant is immediately prevented from logging in or making API calls.

---

## 3. Detailed REST API Specifications for React Dev Team

### Authentication Headers
All Super Admin requests require:
```http
Authorization: Bearer <SUPER_ADMIN_JWT_TOKEN>
Content-Type: application/json
```

---

### 1. Super Admin Authentication

#### `POST /api/superadmin/login`
Authenticates Super Admin and returns a JWT token.

* **Request Body**:
```json
{
  "email": "superadmin@sendzyy.com",
  "password": "SuperSecurePassword123!"
}
```
* **Response (200 OK)**:
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsIn...",
  "admin": {
    "email": "superadmin@sendzyy.com",
    "role": "superadmin"
  }
}
```

---

### 2. Tenant Registration & Management APIs

#### `GET /api/superadmin/tenants`
Lists all tenants with filtering and pagination.

* **Query Parameters**: `page` (default 1), `limit` (default 10), `search` (optional text), `status` (`all` | `active` | `inactive` | `expired`)
* **Response (200 OK)**:
```json
{
  "success": true,
  "total": 45,
  "page": 1,
  "totalPages": 5,
  "tenants": [
    {
      "id": "66b1a2b3c4d5e6f7a8b9c0d1",
      "name": "Care Plus Clinic",
      "email": "careplus@gmail.com",
      "status": "active",
      "subscription": {
        "planId": "panel_12m",
        "planName": "12 Month Access",
        "price": 14999,
        "expiryDate": "2027-08-08T10:00:00.000Z",
        "lastPaymentId": "pay_XYZ12345",
        "isExpired": false,
        "daysRemaining": 365
      },
      "whatsappConfig": {
        "verified": true,
        "displayPhone": "+91 98765 43210",
        "phoneStatus": "CONNECTED"
      },
      "createdAt": "2026-08-08T10:00:00.000Z"
    }
  ]
}
```

#### `POST /api/superadmin/tenants/register-manual`
Directly registers a tenant after manual/offline payment clearance.

* **Request Body**:
```json
{
  "name": "Acme Healthcare",
  "email": "contact@acmehealth.com",
  "password": "TemporaryPassword123!",
  "planId": "panel_12m",
  "paymentReference": "CASH_REF_9988",
  "sendCredentialsEmail": true
}
```
* **Response (201 Created)**:
```json
{
  "success": true,
  "message": "Tenant registered and activated successfully.",
  "tenant": {
    "id": "66b1a2b3c4d5e6f7a8b9c0d2",
    "name": "Acme Healthcare",
    "email": "contact@acmehealth.com",
    "status": "active",
    "subscription": {
      "planId": "panel_12m",
      "planName": "12 Month Access",
      "expiryDate": "2027-08-08T10:00:00.000Z"
    }
  }
}
```

#### `PATCH /api/superadmin/tenants/:id/status`
Toggles tenant account status (`active` or `inactive`).

* **Request Body**:
```json
{
  "status": "inactive"
}
```
* **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Tenant status updated to inactive",
  "tenant": {
    "id": "66b1a2b3c4d5e6f7a8b9c0d1",
    "name": "Care Plus Clinic",
    "email": "careplus@gmail.com",
    "status": "inactive"
  }
}
```

---

### 3. Package Management APIs

#### `GET /api/superadmin/packages`
Lists all packages (active and inactive).

* **Response (200 OK)**:
```json
{
  "success": true,
  "packages": [
    {
      "id": "66b1a2b3c4d5e6f7a8b9c0d5",
      "planId": "panel_1m",
      "name": "1 Month Access",
      "description": "1 month full panel access",
      "basePrice": 1270,
      "gstPercent": 18,
      "totalPrice": 1499,
      "panelDays": 30,
      "isActive": true
    }
  ]
}
```

#### `POST /api/superadmin/packages`
Creates a new panel package.

* **Request Body**:
```json
{
  "planId": "panel_custom_6m",
  "name": "6 Month Pro Pass",
  "description": "Custom 6-month enterprise access",
  "basePrice": 6355,
  "gstPercent": 18,
  "panelDays": 180,
  "isActive": true
}
```
* **Response (201 Created)**:
```json
{
  "success": true,
  "message": "Package created successfully",
  "package": {
    "planId": "panel_custom_6m",
    "name": "6 Month Pro Pass",
    "totalPrice": 7499,
    "panelDays": 180,
    "isActive": true
  }
}
```

#### `PUT /api/superadmin/packages/:id`
Edits an existing package.

* **Request Body**:
```json
{
  "name": "6 Month Executive Pass",
  "basePrice": 6500,
  "gstPercent": 18,
  "panelDays": 180,
  "isActive": true
}
```
* **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Package updated successfully",
  "package": { ... }
}
```

#### `DELETE /api/superadmin/packages/:id`
Deactivates (soft deletes) a package.

* **Response (200 OK)**:
```json
{
  "success": true,
  "message": "Package deactivated successfully"
}
```

---

### 4. Dashboard Overview & Analytics API

#### `GET /api/superadmin/dashboard-stats`
Returns system-wide metrics for the React Super Admin dashboard home screen.

* **Response (200 OK)**:
```json
{
  "success": true,
  "stats": {
    "totalTenants": 120,
    "activeTenants": 110,
    "inactiveTenants": 10,
    "expiredSubscriptions": 5,
    "totalPackages": 4,
    "totalRevenueINR": 450000
  }
}
```

---

## 4. Verification & Testing Plan

1. **Unit & Integration Tests**:
   - `superadmin_auth.test.js`: Validates Super Admin login and JWT role authorization.
   - `tenant_registration_payment.test.js`: Verifies that unpaid tenants are NOT stored in MongoDB and cannot log in.
   - `package_crud.test.js`: Verifies package creation, editing, soft deletion, and ensuring active packages are correctly exposed via `GET /panel-plans`.
   - `tenant_status_toggle.test.js`: Verifies active/inactive state change and instant login restriction enforcement.

2. **Regression Assurance**:
   - Run existing backend test suite (`npm test`).
   - Confirm standard tenant registration (`/register-step1` & `/verify-panel-payment`) remains unchanged.
   - Confirm Flutter mobile app API endpoints (`/api/clients`, `/api/notifications`, `/login`) continue operating without any breaking changes.
