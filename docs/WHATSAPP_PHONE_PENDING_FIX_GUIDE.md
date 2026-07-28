# WhatsApp Cloud API — Phone Number `PENDING` Status: Root Cause & Complete Fix Guide

> **Platform:** Sendzyy WhatsApp Marketing SaaS (Tech Provider / Solution Provider Model)  
> **API Version:** Meta Graph API `v25.0`  
> **Incident Type:** Production — Multiple Customers Affected  
> **Symptom:** Phone status stuck at `PENDING` · Error `141000` returned on every message attempt  

---

## 🔴 The Exact Problem

After a client completes Embedded Signup, everything appears successful:

| Signal | Value |
|--------|-------|
| `code_verification_status` | `VERIFIED` ✅ |
| `verified_name` | Present ✅ |
| `waba_id` | Received ✅ |
| `phone_number_id` | Received ✅ |
| Webhook subscribed | Yes ✅ |
| **Phone `status`** | **`PENDING` ❌** |
| **Message send / Health API** | **Error `141000` ❌** |

**Meta Error 141000:**
> *"The phone number you are trying to send messages from is not linked to your WhatsApp account."*

---

## 🧠 Why This Happens — The Missing Step

Meta Embedded Signup does **two separate things**:

```
Embedded Signup popup
  │
  ├─► Creates phone number object inside WABA
  │     code_verification_status = VERIFIED  (via 6-digit OTP)
  │     name_approval_status = PENDING_REVIEW / APPROVED
  │
  └─► Does NOT provision the WhatsApp Cloud API container
        (No encryption keys, no messaging container, no link to Cloud API)
```

The phone object exists in Meta's database, but the **WhatsApp Cloud API messaging infrastructure container** is never spun up until you explicitly call:

```
POST /v25.0/{PHONE_NUMBER_ID}/register
```

Without this call:
- `phone.status` stays `PENDING` forever
- Health API → Error `141000`
- Message send API → Error `141000`

> **This call is mandatory. Meta does NOT call it automatically. Ever.**

---

## 📋 Complete 11-Stage Onboarding Flow (Correct Implementation)

```
Stage 1  ─► Frontend Launch (FB.login with config_id)
             └── JS SDK v25.0, sessionInfoVersion: '3', response_type: 'code'

Stage 2  ─► Customer Popup
             └── Logs in, picks Business Manager, adds phone, enters 6-digit OTP
                 Meta sets: code_verification_status = VERIFIED

Stage 3  ─► PostMessage Event Capture (window.addEventListener)
             └── Captures: waba_id, phone_number_id, business_portfolio_id, code

Stage 4  ─► Backend OAuth Token Exchange
             GET /v25.0/oauth/access_token?client_id=&client_secret=&code=
             └── Returns: 60-day User Access Token

Stage 5  ─► Debug Token Inspection
             GET /v25.0/debug_token
             └── Validates scopes and expiry

Stage 6  ─► Tech Provider System User Token Exchange
             POST /v25.0/{businessPortfolioId}/system_user_access_tokens
             └── Returns: NEVER-EXPIRING permanent business token

Stage 7  ─► Query Phone Number Details
             GET /v25.0/{wabaId}/phone_numbers
             ?fields=id,display_phone_number,verified_name,
                     code_verification_status,name_approval_status,
                     status,quality_rating,throughput
             └── Gets: phoneNumberId, nameApprovalStatus, codeVerificationStatus, status

Stage 8  ─► Subscribe WABA Webhooks
             POST /v25.0/{wabaId}/subscribed_apps
             └── Fields: messages, account_update, phone_number_name_update

Stage 9  ─► ⭐ PHONE NUMBER REGISTRATION (THE MISSING STEP)
             POST /v25.0/{PHONE_NUMBER_ID}/register
             Body: { messaging_product: "whatsapp", pin: "123456" }
             └── Provisions Cloud API container & encryption keys
                 phone.status changes: PENDING → CONNECTED

Stage 10 ─► Webhook Listener: phone_number_name_update
             └── If name approval comes asynchronously AFTER onboarding,
                 auto-triggers Stage 9 on decision === "APPROVED"

Stage 11 ─► Finalization
             └── phone.status = CONNECTED
                 Tenant DB: verified: true, phoneStatus: CONNECTED
                 Messaging is now operational
```

---

## 🔑 Step 10 Deep Dive: `POST /{PHONE_NUMBER_ID}/register`

### Official Meta API Specification

| Property | Value |
|----------|-------|
| **Method** | `POST` |
| **Endpoint** | `https://graph.facebook.com/v25.0/{PHONE_NUMBER_ID}/register` |
| **Auth** | `Authorization: Bearer {SYSTEM_USER_ACCESS_TOKEN}` |
| **Body** | `{ "messaging_product": "whatsapp", "pin": "123456" }` |
| **Permission Required** | `whatsapp_business_management` |
| **Success Response** | `{ "success": true }` |
| **Effect** | Provisions Cloud API container, sets `status = CONNECTED` |

### When to Call It

Call `POST /{PHONE_NUMBER_ID}/register` when **either** of these is true:
- `code_verification_status === "VERIFIED"` — phone OTP was completed
- `name_approval_status === "APPROVED"` — display name was approved by Meta

### What PIN to Use

The 6-digit PIN is a **recovery PIN** you define for the platform. Use any fixed default like `123456` — it is **not** the customer's OTP. Store it if you want to allow future deregistration/re-registration.

---

## 🏗️ How We Implemented the Fix

### 1. The `registerPhoneNumber` Helper Function (`backend/server.js`)

```javascript
/**
 * Registers a phone number with Meta WhatsApp Cloud API.
 * Provisions the Cloud API container and transitions phone
 * status from PENDING to CONNECTED.
 *
 * @param {string} phoneNumberId - Meta Phone Number ID
 * @param {string} accessToken   - System User or Valid Access Token
 * @param {string} pin           - 6-digit registration PIN (default: '123456')
 */
async function registerPhoneNumber(phoneNumberId, accessToken, pin = '123456') {
    const apiVersion = process.env.META_API_VERSION || 'v25.0';
    const url = `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/register`;

    try {
        const response = await axios.post(
            url,
            { messaging_product: 'whatsapp', pin: pin || '123456' },
            { headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            }}
        );
        console.log(`[registerPhoneNumber] ✅ Phone ID ${phoneNumberId} registered:`, response.data);
        return { success: true, data: response.data };
    } catch (err) {
        const errData = err.response?.data || err.message;
        console.error(`[registerPhoneNumber] ❌ Registration failed:`, JSON.stringify(errData, null, 2));
        return { success: false, error: errData };
    }
}
```

---

### 2. Auto-Registration Inside `processOnboarding()` (`backend/server.js`)

After querying phone details (Stage 7), this block auto-triggers registration:

```javascript
// Condition: either OTP verified OR name approved is sufficient
const tokenForRegistration = businessToken || systemToken;

if (
    phoneNumberId &&
    tokenForRegistration &&
    (codeVerificationStatus === 'VERIFIED' || nameApprovalStatus === 'APPROVED')
) {
    const regResult = await registerPhoneNumber(phoneNumberId, tokenForRegistration, '123456');

    if (regResult.success) {
        phoneStatus = 'CONNECTED';
    } else {
        registrationError = regResult.error;
        // phoneStatus remains 'PENDING' — tenant can retry manually via dashboard
    }
}
```

---

### 3. Manual Retry REST Endpoint (`backend/server.js`)

For customers already stuck in `PENDING` before the fix was deployed:

```javascript
app.post('/api/whatsapp/register-phone', authenticate, async (req, res) => {
    const tenant = await Tenant.findById(req.user.tenantId);
    const config = tenant.whatsappConfig;

    const pin = req.body?.pin || config?.registrationPin || '123456';
    const result = await registerPhoneNumber(config.phoneNumberId, config.accessToken, pin);

    if (result.success) {
        await Tenant.findByIdAndUpdate(req.user.tenantId, {
            $set: {
                'whatsappConfig.phoneStatus': 'CONNECTED',
                'whatsappConfig.verified': true,
                'whatsappConfig.registrationError': null,
            }
        });
        return res.json({ success: true });
    }
    return res.status(500).json({ success: false, error: result.error });
});
```

---

### 4. Webhook Auto-Registration on Display Name Approval (`backend/server.js`)

Meta approves display names **asynchronously** — sometimes minutes or hours after onboarding completes. This handler catches it:

```javascript
// Inside app.post('/webhook'), in the entry/change loop:

if (change.field === 'phone_number_name_update') {
    const decision    = change.value?.decision;
    const phoneNumberId = change.value?.phone_number_id;

    if (decision === 'APPROVED' && phoneNumberId) {
        const tenant = await Tenant.findOne({ 'whatsappConfig.phoneNumberId': phoneNumberId });

        if (tenant?.whatsappConfig?.accessToken) {
            const regResult = await registerPhoneNumber(
                phoneNumberId, tenant.whatsappConfig.accessToken, '123456'
            );
            if (regResult.success) {
                await Tenant.findByIdAndUpdate(tenant._id, {
                    $set: {
                        'whatsappConfig.phoneStatus': 'CONNECTED',
                        'whatsappConfig.nameApprovalStatus': 'APPROVED',
                        'whatsappConfig.verified': true,
                    }
                });
            }
        }
    }
}
```

---

### 5. Flutter Dashboard Button (`lib/features/settings/presentation/pages/settings_page.dart`)

Shown directly on the **Meta Account Connected** card in **Settings → General Settings**:

```dart
Future<void> _registerPhoneWithMeta() async {
    setState(() => _isRegisteringPhone = true);
    final res = await getIt<WhatsAppRepository>().registerPhoneNumber();
    setState(() => _isRegisteringPhone = false);

    if (res != null && res['success'] == true) {
        context.read<AuthBloc>().add(AuthCheckRequested()); // refresh state
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Phone registered! Status is now CONNECTED.'),
            backgroundColor: Colors.green,
        ));
    }
}

// Button widget:
ElevatedButton.icon(
    onPressed: _isRegisteringPhone ? null : _registerPhoneWithMeta,
    icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
    label: const Text('Register Phone Number (Fix Error 141000)'),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
),
```

---

### 6. Mongoose Schema — New Fields Added (`backend/server.js`)

```javascript
whatsappConfig: {
    // ... existing fields ...
    nameApprovalStatus:      { type: String, default: 'UNKNOWN' },
    codeVerificationStatus:  { type: String, default: 'UNKNOWN' },
    phoneStatus:             { type: String, default: 'PENDING' },
    registrationPin:         { type: String, default: '123456' },
    registrationError:       { type: mongoose.Schema.Types.Mixed, default: null },
    tokenType:               { type: String, default: 'user' },
    tokenStatus:             { type: String, default: 'active' },
    tokenExpiry:             { type: Date, default: null },
}
```

---

## 🔑 Which Token to Use for Registration

| Token Type | Can Register? | Notes |
|-----------|:-------------:|-------|
| Customer System User Token (permanent) | ✅ Best | Generated via `POST /{businessPortfolioId}/system_user_access_tokens` |
| Tech Provider System User Token (`META_SYSTEM_TOKEN`) | ✅ Fallback | Has admin access to all partner WABAs |
| 60-day User Access Token (from OAuth) | ⚠️ Temporary | Works but expires; replace with permanent token |
| App Access Token (`app_id\|app_secret`) | ❌ No | App-level only — cannot access WABA resources |

**In code:**
```javascript
const tokenForRegistration = businessToken || systemToken;
//  businessToken = permanent customer system user token (preferred)
//  systemToken   = META_SYSTEM_TOKEN from .env (fallback)
```

---

## 🔁 When Registration Is Skipped & What To Do

| Skip Reason | Log Event | Resolution |
|------------|-----------|-----------|
| `code_verification_status !== 'VERIFIED'` | `REGISTER_PHONE_SKIPPED` | Customer didn't complete OTP. Ask to redo Embedded Signup. |
| `name_approval_status` is `PENDING_REVIEW` | `REGISTER_PHONE_SKIPPED` | Wait — `phone_number_name_update` webhook will auto-retry when Meta approves. |
| No system token in `.env` | `SKIPPED_NO_SYSTEM_TOKEN` | Set `META_SYSTEM_TOKEN` in backend `.env`. |
| No `phoneNumberId` available | `FETCH_PHONE_EMPTY` | Customer left popup before adding a phone number. Ask to re-onboard. |

---

## ✅ How to Verify Registration Succeeded

### Check Server Logs
```
[registerPhoneNumber] ✅ Phone ID 123456789 successfully registered: { success: true }
```

### Query Meta Graph API
```bash
curl "https://graph.facebook.com/v25.0/{PHONE_NUMBER_ID}?fields=id,status&access_token={TOKEN}"
# Expected: { "id": "...", "status": "CONNECTED" }
```

### Check MongoDB
```javascript
db.tenants.findOne(
  { 'whatsappConfig.phoneNumberId': '123456789' },
  { 'whatsappConfig.phoneStatus': 1, 'whatsappConfig.verified': 1 }
)
// Expected: { phoneStatus: 'CONNECTED', verified: true }
```

### Health Check API
```bash
curl "https://graph.facebook.com/v25.0/{PHONE_NUMBER_ID}/health_status" \
  -H "Authorization: Bearer {TOKEN}"
# Expected: { "can_send_message": "AVAILABLE" }  ← no Error 141000
```

---

## 🛑 Common Registration Errors & Fixes

| Error Code | Message | Cause | Fix |
|-----------|---------|-------|-----|
| `141000` | Phone not linked to account | `/register` was never called | Call `POST /{phone_id}/register` |
| `100` | Invalid parameter | Wrong phone_number_id format | Use Meta numeric ID, not display number |
| `190` | Access token expired | 60-day token expired | Use permanent system user token |
| `10` | Permission denied | Token lacks `whatsapp_business_management` | Use system user token with correct scope |
| `368` | Account in violation | WABA policy violation | Customer must resolve in Meta Business Manager |
| `130472` | Not associated with WABA | Wrong WABA/phone ID pair | Verify IDs in Meta Business Manager |

---

## 📋 Webhook Fields Checklist (Meta Developer Portal)

Navigate to **Meta App Dashboard → WhatsApp → Configuration → Webhook Fields** and confirm all are subscribed:

| Field | Purpose | Required |
|-------|---------|:--------:|
| `messages` | Inbound messages & delivery receipts | ✅ |
| `account_update` | `PARTNER_ADDED` for new Embedded Signup | ✅ |
| `phone_number_name_update` | Display name approved → auto-registers phone | ✅ |
| `message_template_status_update` | Template `APPROVED`/`REJECTED` notifications | ✅ |

---

## 🛠️ Manual Fix for Legacy PENDING Accounts

For any customer onboarded **before** this fix was deployed:

1. Go to **Settings → General Settings** in the Sendzyy dashboard.
2. Find the green **"Meta Account Connected"** card.
3. Click: **"Register Phone Number (Fix Error 141000)"** button.
4. Wait 2–5 seconds for Meta API to respond.
5. ✅ Green snackbar confirms success. Client can now send messages.

**Or via direct API call:**
```bash
curl -X POST https://app.sendzyy.com/api/whatsapp/register-phone \
  -H "Authorization: Bearer {TENANT_JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"pin": "123456"}'
```

---

## 📁 Files Modified in This Fix

| File | Change |
|------|--------|
| [`backend/server.js`](file:///c:/Users/Admin/Downloads/Sendzyy/sendzyy/backend/server.js) | `registerPhoneNumber()` helper · `processOnboarding()` auto-registration · `POST /api/whatsapp/register-phone` endpoint · `phone_number_name_update` webhook handler · Mongoose schema new fields |
| [`backend/.env`](file:///c:/Users/Admin/Downloads/Sendzyy/sendzyy/backend/.env) | Standardized `META_API_VERSION=v25.0` |
| [`web/index.html`](file:///c:/Users/Admin/Downloads/Sendzyy/sendzyy/web/index.html) | FB JS SDK version set to `v25.0` |
| [`lib/features/whatsapp/data/repositories/whatsapp_repository.dart`](file:///c:/Users/Admin/Downloads/Sendzyy/sendzyy/lib/features/whatsapp/data/repositories/whatsapp_repository.dart) | Added `registerPhoneNumber()` Dart method calling `/api/whatsapp/register-phone` |
| [`lib/features/settings/presentation/pages/settings_page.dart`](file:///c:/Users/Admin/Downloads/Sendzyy/sendzyy/lib/features/settings/presentation/pages/settings_page.dart) | `_registerPhoneWithMeta()` handler + green action button on Meta Connected card |

---

## 🔮 Pre-Launch Checklist (Prevent This From Ever Happening Again)

Before going live with any new customer, verify:

- [ ] `META_SYSTEM_TOKEN` is set in `.env` and belongs to an **Admin System User** (not a personal account)
- [ ] Meta App is in **Live Mode** with **Advanced Access** for `whatsapp_business_management` and `whatsapp_business_messaging`
- [ ] Embedded Signup Config ID is correct in **Meta App → WhatsApp → Embedded Signup**
- [ ] Webhook is verified and all 4 fields are subscribed
- [ ] After onboarding, MongoDB shows `phoneStatus: "CONNECTED"` and `verified: true`
- [ ] Test message sends successfully to a real WhatsApp number

---

*Document created: July 24, 2026 · Sendzyy Engineering · Meta Graph API v25.0*
