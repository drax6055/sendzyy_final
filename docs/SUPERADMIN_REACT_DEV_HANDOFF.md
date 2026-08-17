# Sendzyy Super Admin — React Dev Handoff & Integration Guide

> **Audience**: React Developer building the Super Admin portal  
> **Backend URL**: Configured via `API_BASE_URL` env (e.g. `https://api.sendzyy.com`)  
> **Status**: Backend fully implemented in `server.js` — ready to integrate

---

## 1. Overview

The Super Admin portal allows Sendzyy's internal team to:

| Feature | Description |
|---|---|
| **Login** | Super Admin authenticates with dedicated credentials |
| **Tenant Registration (Manual)** | Register tenant after cash/bank offline payment — no Razorpay needed |
| **Tenant Registration (Online Invite)** | Send Razorpay payment invite to tenant email — account created only after payment |
| **Tenant Listing** | View all tenants with search, pagination, and status filters |
| **Tenant Status Toggle** | Activate or deactivate any tenant's account (blocks login instantly) |
| **Package Management** | Create, edit, and deactivate subscription packages |
| **Dashboard Stats** | System-wide metrics: tenant counts, revenue breakdown |

---

## 2. Environment Setup (Backend)

Add the following to the backend `.env` file on the server:

```bash
# Generate a strong unique secret (NOT the same as JWT_SECRET):
# node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
SUPERADMIN_JWT_SECRET=<generated_value>

SUPERADMIN_EMAIL=superadmin@sendzyy.com

# Generate bcrypt hash of the admin password:
# node -e "require('bcrypt').hash('YourChosenPassword', 10).then(console.log)"
SUPERADMIN_PASSWORD_HASH=<bcrypt_hash>
```

> ⚠️ **These values must NEVER be committed to GitHub.**

---

## 3. Authentication

All Super Admin API requests require the `Authorization: Bearer <token>` header.

### `POST /api/superadmin/login`

```http
POST /api/superadmin/login
Content-Type: application/json

{
  "email": "superadmin@sendzyy.com",
  "password": "YourChosenPassword"
}
```

**Response (200)**:
```json
{
  "success": true,
  "token": "eyJhbGci...",
  "admin": { "email": "superadmin@sendzyy.com", "role": "superadmin" }
}
```

> Store this token in React state/localStorage. It expires after **12 hours**. All subsequent requests must send:
> ```http
> Authorization: Bearer <token>
> ```

---

## 4. Tenant APIs

### 4.1 List All Tenants

```http
GET /api/superadmin/tenants
Authorization: Bearer <token>
```

**Query Parameters**:

| Param | Default | Description |
|---|---|---|
| `page` | `1` | Page number |
| `limit` | `10` | Results per page |
| `search` | `` | Name or email search |
| `status` | `all` | `all` / `active` / `inactive` / `expired` |

> ⚠️ **Important**: `expired` is a **computed state** — tenants whose account is `active` but `subscription.expiryDate < now`. Use `computedStatus` field in the response for display.

**Response (200)**:
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
      "computedStatus": "active",
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
      "createdAt": "2026-08-08T10:00:00.000Z",
      "updatedAt": "2026-08-08T10:00:00.000Z"
    }
  ]
}
```

---

### 4.2 Register Tenant — Mode 1: Manual (Cash/Bank)

Used when the tenant pays offline (cash, bank transfer). Super Admin provides clearance directly.

```http
POST /api/superadmin/tenants/register-manual
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Acme Healthcare",
  "email": "contact@acmehealth.com",
  "password": "TemporaryPassword123!",
  "planId": "panel_12m",
  "paymentReference": "BANK_TXN_REF_12345",
  "sendWelcomeEmail": true
}
```

| Field | Required | Notes |
|---|---|---|
| `name` | ✅ | Business name |
| `email` | ✅ | Must be unique |
| `password` | ✅ | Temporary password shown in welcome email |
| `planId` | ✅ | Use planId from `GET /api/superadmin/packages` |
| `paymentReference` | Optional | Cash/bank reference number for records |
| `sendWelcomeEmail` | Optional (default: `true`) | Send credentials to tenant email |

**Response (201)**:
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

> ℹ️ The tenant can log in immediately after this call using the email and password provided.

---

### 4.3 Register Tenant — Mode 2: Online Payment Invite

Used when tenant pays online via Razorpay (Live). Super Admin creates an invite; tenant pays; account is created only after payment succeeds.

**Step 1 — Super Admin creates invite:**
```http
POST /api/superadmin/tenants/create-payment-invite
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Bright Dental Clinic",
  "email": "bright@dental.com",
  "planId": "panel_6m"
}
```

**Response (200)**:
```json
{
  "success": true,
  "message": "Payment invite created.",
  "inviteToken": "eyJhbGci...",
  "razorpayOrder": {
    "orderId": "order_XXXXX",
    "amount": 7499,
    "currency": "INR",
    "planName": "6 Month Access",
    "panelDays": 180
  }
}
```

> ℹ️ The React portal should send the `inviteToken` and `orderId` to the tenant (embed in a payment link page). The invite token is valid for **72 hours**.

**Step 2 — Tenant completes Razorpay payment and submits to verify:**
```http
POST /api/superadmin/tenants/verify-payment-invite
Content-Type: application/json

{
  "inviteToken": "eyJhbGci...",
  "razorpay_order_id": "order_XXXXX",
  "razorpay_payment_id": "pay_YYYYY",
  "razorpay_signature": "<hmac_signature>"
}
```

**Response (200)**:
```json
{
  "success": true,
  "message": "Account created successfully. Login credentials have been emailed.",
  "tenant": {
    "id": "66b1a2b3c4d5e6f7a8b9c0d3",
    "name": "Bright Dental Clinic",
    "email": "bright@dental.com",
    "status": "active",
    "subscription": {
      "planId": "panel_6m",
      "planName": "6 Month Access",
      "expiryDate": "2027-02-08T10:00:00.000Z"
    }
  }
}
```

> ⚠️ **No auth token required** for `verify-payment-invite` — the tenant's browser calls this endpoint directly after Razorpay payment completes.  
> The tenant receives a **welcome email** with an **auto-generated temporary password** (16-char hex). They should change it after first login.

---

### 4.4 Toggle Tenant Status (Active / Inactive)

```http
PATCH /api/superadmin/tenants/:id/status
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "inactive"
}
```

> ⚠️ Setting `"inactive"` **immediately blocks** the tenant from logging in. The `/login` endpoint returns `403 account_inactive`. No data is deleted.

**Response (200)**:
```json
{
  "success": true,
  "message": "Tenant status updated to inactive",
  "tenant": {
    "id": "66b1a2b3c4d5e6f7a8b9c0d1",
    "name": "Care Plus Clinic",
    "email": "careplus@gmail.com",
    "status": "inactive",
    "subscription": { ... },
    "updatedAt": "2026-08-08T10:00:00.000Z"
  }
}
```

---

## 5. Package APIs

### 5.1 List All Packages (including inactive)

```http
GET /api/superadmin/packages
Authorization: Bearer <token>
```

**Response (200)**:
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
      "isActive": true,
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

---

### 5.2 Create Package

```http
POST /api/superadmin/packages
Authorization: Bearer <token>
Content-Type: application/json

{
  "planId": "panel_custom_6m",
  "name": "6 Month Pro Pass",
  "description": "Custom 6-month access",
  "basePrice": 6355,
  "gstPercent": 18,
  "panelDays": 180,
  "isActive": true
}
```

> ℹ️ `totalPrice` is **auto-computed** by the backend: `Math.round(basePrice * (1 + gstPercent / 100))`. Do not send it from the React UI.

**Response (201)**:
```json
{
  "success": true,
  "message": "Package created successfully",
  "package": {
    "id": "...",
    "planId": "panel_custom_6m",
    "name": "6 Month Pro Pass",
    "basePrice": 6355,
    "gstPercent": 18,
    "totalPrice": 7499,
    "panelDays": 180,
    "isActive": true,
    "createdAt": "..."
  }
}
```

---

### 5.3 Edit Package

```http
PUT /api/superadmin/packages/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "6 Month Executive Pass",
  "basePrice": 6500,
  "gstPercent": 18,
  "panelDays": 180,
  "isActive": true
}
```

> ℹ️ Send only the fields you want to change. `totalPrice` is recomputed automatically if `basePrice` or `gstPercent` changes.

**Response (200)**:
```json
{
  "success": true,
  "message": "Package updated successfully",
  "package": {
    "id": "...",
    "planId": "panel_custom_6m",
    "name": "6 Month Executive Pass",
    "basePrice": 6500,
    "gstPercent": 18,
    "totalPrice": 7670,
    "panelDays": 180,
    "isActive": true,
    "updatedAt": "..."
  }
}
```

---

### 5.4 Delete Package (Hard Delete)

```http
DELETE /api/superadmin/packages/:id
Authorization: Bearer <token>
```

> ⚠️ This **permanently removes** the package from MongoDB. If any **active tenants** are subscribed to this plan, the request will be **rejected** with a `409 Conflict` error:
> ```json
> { "error": "Cannot delete package. 3 active tenant(s) are currently on this plan.", "activeTenantCount": 3 }
> ```

**Success Response (200)**:
```json
{
  "success": true,
  "message": "Package '6 Month Pro Pass' deleted permanently.",
  "package": { "id": "...", "planId": "panel_custom_6m", "name": "6 Month Pro Pass" }
}
```

---

## 6. Dashboard Stats

```http
GET /api/superadmin/dashboard-stats
Authorization: Bearer <token>
```

**Response (200)**:
```json
{
  "success": true,
  "stats": {
    "totalTenants": 120,
    "activeTenants": 110,
    "inactiveTenants": 5,
    "expiredSubscriptions": 5,
    "totalActivePackages": 4,
    "revenue": {
      "totalINR": 450000,
      "onlinePaymentsINR": 430000,
      "manualPaymentsINR": 20000
    }
  }
}
```

---

## 7. Error Responses

All endpoints use standard HTTP status codes:

| Status | Meaning |
|---|---|
| `200` | Success |
| `201` | Created |
| `400` | Bad Request (missing fields, invalid data) |
| `401` | Unauthorized (no token or expired token) |
| `403` | Forbidden (wrong role or invalid token) |
| `404` | Resource not found |
| `409` | Conflict (e.g. email already registered, package has active tenants) |
| `500` | Server error |

---

## 8. Merging Sendzyy Backend with Master Admin (React App)

Follow these steps to merge the backend into your React project setup:

### Step 1 — Set Backend Env Variables on Server
SSH into the production server and update the `.env` file:
```bash
# Generate SUPERADMIN_JWT_SECRET
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

# Generate SUPERADMIN_PASSWORD_HASH
node -e "require('bcrypt').hash('YourChosenAdminPassword', 10).then(console.log)"
```
Add to `.env`:
```
SUPERADMIN_JWT_SECRET=<output from first command>
SUPERADMIN_EMAIL=superadmin@sendzyy.com
SUPERADMIN_PASSWORD_HASH=<output from second command>
```

### Step 2 — Restart Backend Server
```bash
pm2 restart sendzyy-backend
# or
node server.js
```

### Step 3 — Configure React App Base URL
In your React app, set the API base URL pointing to the Sendzyy backend:
```js
// .env.local (React)
REACT_APP_API_BASE_URL=https://api.sendzyy.com
```

### Step 4 — Implement Login Flow in React
```js
const login = async (email, password) => {
  const res = await fetch(`${process.env.REACT_APP_API_BASE_URL}/api/superadmin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json();
  if (data.success) {
    localStorage.setItem('superadmin_token', data.token);
  }
};
```

### Step 5 — Create Axios/Fetch Interceptor
Create a reusable API client that injects the token automatically:
```js
const apiClient = async (path, options = {}) => {
  const token = localStorage.getItem('superadmin_token');
  const res = await fetch(`${process.env.REACT_APP_API_BASE_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (res.status === 401 || res.status === 403) {
    localStorage.removeItem('superadmin_token');
    window.location.href = '/login';
    return;
  }
  return res.json();
};
```

### Step 6 — Implement Mode 2 Razorpay Payment Flow (if needed in React portal)
If you want the React admin portal to show the Razorpay payment UI (for the invite flow):
1. Call `POST /api/superadmin/tenants/create-payment-invite` → get `orderId` and `inviteToken`
2. Load Razorpay checkout script in React:
   ```js
   const script = document.createElement('script');
   script.src = 'https://checkout.razorpay.com/v1/checkout.js';
   document.body.appendChild(script);
   ```
3. Open checkout with the received `orderId` and `amount`
4. On `handler` callback, call `POST /api/superadmin/tenants/verify-payment-invite` with the payment details + `inviteToken`

### Step 7 — Test All Endpoints
Use the test checklist below before going live:
- [ ] `POST /api/superadmin/login` — Valid credentials return token
- [ ] `POST /api/superadmin/login` — Invalid credentials return 401
- [ ] `GET /api/superadmin/tenants` — Returns paginated tenant list
- [ ] `GET /api/superadmin/tenants?status=expired` — Returns only expired tenants
- [ ] `POST /api/superadmin/tenants/register-manual` — Creates active tenant, welcome email sent
- [ ] `POST /api/superadmin/tenants/register-manual` — Rejects duplicate email (409)
- [ ] `POST /api/superadmin/tenants/create-payment-invite` — Returns inviteToken + orderId
- [ ] `POST /api/superadmin/tenants/verify-payment-invite` — Creates tenant after payment
- [ ] `PATCH /api/superadmin/tenants/:id/status` — Toggle inactive blocks login (test via `/login` endpoint)
- [ ] `GET /api/superadmin/packages` — Returns all packages including inactive
- [ ] `POST /api/superadmin/packages` — Creates package, totalPrice auto-computed
- [ ] `PUT /api/superadmin/packages/:id` — Updates package, totalPrice recomputed
- [ ] `DELETE /api/superadmin/packages/:id` — Blocks if active tenants on plan (409)
- [ ] `DELETE /api/superadmin/packages/:id` — Soft-deletes if no active tenants
- [ ] `GET /api/superadmin/dashboard-stats` — Returns correct counts and revenue split
- [ ] **Regression**: `POST /login` (tenant) — Still works normally for existing tenants
- [ ] **Regression**: `GET /api/clients` (tenant) — Super Admin token cannot access tenant routes

---

## 9. Security Notes for React Dev

| Rule | Detail |
|---|---|
| **Do NOT share JWT_SECRET** | The Super Admin uses `SUPERADMIN_JWT_SECRET` — a completely different secret |
| **Never log tokens** | Do not `console.log` the JWT token in production |
| **Token expiry** | Super Admin token expires in 12h — handle 401/403 by redirecting to login |
| **Package delete guard** | Always show `activeTenantCount` to admin before confirming delete |
| **Password display** | In Mode 1, show a warning to admin: "Share this password securely with the tenant" |
