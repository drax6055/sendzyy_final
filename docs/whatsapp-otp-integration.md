# WhatsApp OTP Authentication — Integration Guide

> Complete guide to adding WhatsApp-based OTP login to your website or mobile app using the iFloraBuzz API.

---

## Table of Contents

1. [How It Works](#how-it-works)
2. [Prerequisites](#prerequisites)
3. [API Reference](#api-reference)
4. [Web Integration (HTML / Vanilla JS)](#web-integration)
5. [React Integration](#react-integration)
6. [Next.js Integration](#nextjs-integration)
7. [Flutter / Dart Integration](#flutter-integration)
8. [React Native Integration](#react-native-integration)
9. [Security Best Practices](#security-best-practices)
10. [Troubleshooting](#troubleshooting)

---

## How It Works

```
User enters phone number
        │
        ▼
Your server calls  POST /send-otp
        │
        ▼
iFloraBuzz generates a 6-digit OTP
stores it server-side (10 min TTL)
sends it via WhatsApp template message
        │
        ▼
User receives OTP on WhatsApp
enters it in your UI
        │
        ▼
Your server calls  POST /verify-otp
        │
        ▼
iFloraBuzz validates → returns success
        │
        ▼
You issue your own session / JWT token
```

The OTP is **never exposed to the client** — it lives only on the iFloraBuzz server until verified or expired.

---

## Prerequisites

| Requirement | Details |
|---|---|
| iFloraBuzz account | Sign up and get your API token |
| Meta Business account | Required to send WhatsApp messages |
| AUTHENTICATION template | Must be **APPROVED** in Meta Business Manager |
| WhatsApp Business phone number | Configured in iFloraBuzz settings |

### Creating an AUTHENTICATION Template

1. Log in to iFloraBuzz → **Templates** → **Create Template**
2. Set **Category** to `AUTHENTICATION`
3. The body will auto-generate as: *"Your verification code is {{1}}. For your security, do not share this code."*
4. Add a **Copy Code** button (type: `OTP`)
5. Submit for Meta approval (usually approved within minutes)
6. Note the **template name** and **language code** — you'll need both

---

## API Reference

**Base URL:** `https://your-iflorabuzz-server.com`

All endpoints require a Bearer token in the `Authorization` header.

```
Authorization: Bearer <your_api_token>  
```

---

### POST `/send-otp`

Generates a 6-digit OTP and delivers it to the given WhatsApp number via your AUTHENTICATION template.

**Request Body**

```json
{
  "to": "+919876543210",
  "templateName": "your_auth_template_name",
  "languageCode": "en"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `to` | string | ✅ | Phone number with country code (E.164 format) |
| `templateName` | string | ✅ | Exact name of your APPROVED AUTHENTICATION template |
| `languageCode` | string | ❌ | Template language code. Defaults to `en` |
**Success Response — 200**

```json
{
  "success": true,
  "wamid": "wamid.HBgNOTE..."
}
```

**Error Responses**

```json
{ "error": "to and templateName are required" }          // 400
{ "error": "WhatsApp not configured" }                   // 400
{ "error": "Failed to send OTP", "details": "..." }      // 500
```

---

### POST `/verify-otp`

Verifies the OTP entered by the user. OTP is single-use and expires after 10 minutes.

**Request Body**

```json
{
  "to": "+919876543210",
  "otp": "482910"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `to` | string | ✅ | Same phone number used in `/send-otp` |
| `otp` | string | ✅ | The 6-digit code entered by the user |

**Success Response — 200**

```json
{
  "success": true,
  "message": "OTP verified successfully."
}
```

**Error Responses**

```json
{ "error": "No OTP found for this number. Please request a new one." }  // 400
{ "error": "OTP has expired. Please request a new one." }               // 400
{ "error": "Incorrect OTP. Please try again." }                         // 400
```

---

## Web Integration

### Plain HTML + Vanilla JavaScript

Drop this into any webpage. No framework required.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Login with WhatsApp OTP</title>
  <style>
    body { font-family: sans-serif; max-width: 400px; margin: 60px auto; padding: 0 20px; }
    input { width: 100%; padding: 10px; margin: 8px 0; border: 1px solid #ccc; border-radius: 8px; box-sizing: border-box; font-size: 16px; }
    button { width: 100%; padding: 12px; background: #25D366; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; }
    button:disabled { background: #aaa; cursor: not-allowed; }
    .error { color: red; font-size: 14px; margin-top: 6px; }
    .success { color: green; font-size: 14px; margin-top: 6px; }
    #step-verify { display: none; }
  </style>
</head>
<body>

  <h2>Login with WhatsApp</h2>

  <!-- Step 1: Enter phone -->
  <div id="step-send">
    <label>WhatsApp Number</label>
    <input id="phone" type="tel" placeholder="+919876543210" />
    <button id="btn-send" onclick="sendOtp()">Send OTP on WhatsApp</button>
    <p id="send-error" class="error"></p>
  </div>

  <!-- Step 2: Enter OTP -->
  <div id="step-verify">
    <p id="sent-to-label"></p>
    <label>Enter OTP</label>
    <input id="otp" type="number" placeholder="6-digit code" maxlength="6" />
    <button id="btn-verify" onclick="verifyOtp()">Verify OTP</button>
    <p><a href="#" onclick="resetFlow()">Change number / Resend</a></p>
    <p id="verify-error" class="error"></p>
  </div>

  <script>
    const API_BASE   = 'https://your-iflorabuzz-server.com';
    const API_TOKEN  = 'YOUR_API_TOKEN';          // keep this server-side in production!
    const TEMPLATE   = 'your_auth_template_name';
    const LANG_CODE  = 'en';

    async function sendOtp() {
      const phone = document.getElementById('phone').value.trim();
      const errEl = document.getElementById('send-error');
      errEl.textContent = '';

      if (!phone.match(/^\+\d{7,15}$/)) {
        errEl.textContent = 'Enter a valid number with country code (e.g. +919876543210)';
        return;
      }

      const btn = document.getElementById('btn-send');
      btn.disabled = true;
      btn.textContent = 'Sending...';

      try {
        const res = await fetch(`${API_BASE}/send-otp`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${API_TOKEN}`,
          },
          body: JSON.stringify({ to: phone, templateName: TEMPLATE, languageCode: LANG_CODE }),
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Failed to send OTP');

        document.getElementById('step-send').style.display = 'none';
        document.getElementById('step-verify').style.display = 'block';
        document.getElementById('sent-to-label').textContent = `OTP sent to ${phone}`;
      } catch (err) {
        errEl.textContent = err.message;
      } finally {
        btn.disabled = false;
        btn.textContent = 'Send OTP on WhatsApp';
      }
    }

    async function verifyOtp() {
      const phone = document.getElementById('phone').value.trim();
      const otp   = document.getElementById('otp').value.trim();
      const errEl = document.getElementById('verify-error');
      errEl.textContent = '';

      const btn = document.getElementById('btn-verify');
      btn.disabled = true;
      btn.textContent = 'Verifying...';

      try {
        const res = await fetch(`${API_BASE}/verify-otp`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${API_TOKEN}`,
          },
          body: JSON.stringify({ to: phone, otp }),
        });

        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Verification failed');

        // ✅ OTP verified — issue your own session here
        alert('Login successful! Redirect or set session now.');
        // window.location.href = '/dashboard';

      } catch (err) {
        errEl.textContent = err.message;
      } finally {
        btn.disabled = false;
        btn.textContent = 'Verify OTP';
      }
    }

    function resetFlow() {
      document.getElementById('step-send').style.display = 'block';
      document.getElementById('step-verify').style.display = 'none';
      document.getElementById('otp').value = '';
      document.getElementById('verify-error').textContent = '';
    }
  </script>

</body>
</html>
```

> ⚠️ **Important:** Never expose your API token in client-side code in production. Proxy the calls through your own backend (see the Next.js section below for the recommended pattern).

---

## React Integration

### Custom Hook + Component

**`src/hooks/useWhatsAppOtp.js`**

```js
import { useState } from 'react';

const API_BASE  = process.env.REACT_APP_API_BASE;   // your backend proxy URL
const TEMPLATE  = process.env.REACT_APP_OTP_TEMPLATE;
const LANG_CODE = process.env.REACT_APP_OTP_LANG || 'en';

export function useWhatsAppOtp() {
  const [step, setStep]       = useState('send');   // 'send' | 'verify' | 'verified'
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');
  const [phone, setPhone]     = useState('');

  async function sendOtp(phoneNumber) {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API_BASE}/api/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: phoneNumber, templateName: TEMPLATE, languageCode: LANG_CODE }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setPhone(phoneNumber);
      setStep('verify');
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function verifyOtp(otp) {
    setLoading(true); setError('');
    try {
      const res = await fetch(`${API_BASE}/api/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: phone, otp }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setStep('verified');
      return true;
    } catch (e) {
      setError(e.message);
      return false;
    } finally {
      setLoading(false);
    }
  }

  function reset() { setStep('send'); setError(''); setPhone(''); }

  return { step, loading, error, phone, sendOtp, verifyOtp, reset };
}
```

**`src/components/WhatsAppLogin.jsx`**

```jsx
import { useState } from 'react';
import { useWhatsAppOtp } from '../hooks/useWhatsAppOtp';

export default function WhatsAppLogin({ onSuccess }) {
  const { step, loading, error, phone, sendOtp, verifyOtp, reset } = useWhatsAppOtp();
  const [phoneInput, setPhoneInput] = useState('');
  const [otpInput, setOtpInput]     = useState('');

  async function handleSend(e) {
    e.preventDefault();
    await sendOtp(phoneInput);
  }

  async function handleVerify(e) {
    e.preventDefault();
    const ok = await verifyOtp(otpInput);
    if (ok) onSuccess?.(phone);   // pass verified phone to parent
  }

  if (step === 'verified') {
    return (
      <div style={styles.card}>
        <span style={styles.checkmark}>✅</span>
        <h3>Verified!</h3>
        <p>You are now logged in.</p>
        <button onClick={reset} style={styles.btn}>Login with another number</button>
      </div>
    );
  }

  return (
    <div style={styles.card}>
      <h2>Login with WhatsApp</h2>

      {step === 'send' && (
        <form onSubmit={handleSend}>
          <input
            style={styles.input}
            type="tel"
            placeholder="+919876543210"
            value={phoneInput}
            onChange={e => setPhoneInput(e.target.value)}
            required
          />
          <button style={styles.btn} type="submit" disabled={loading}>
            {loading ? 'Sending...' : '📲 Send OTP on WhatsApp'}
          </button>
        </form>
      )}

      {step === 'verify' && (
        <form onSubmit={handleVerify}>
          <p style={{ color: '#555' }}>OTP sent to <strong>{phone}</strong></p>
          <input
            style={{ ...styles.input, textAlign: 'center', letterSpacing: 8, fontSize: 22 }}
            type="number"
            placeholder="------"
            maxLength={6}
            value={otpInput}
            onChange={e => setOtpInput(e.target.value)}
            required
          />
          <button style={styles.btn} type="submit" disabled={loading}>
            {loading ? 'Verifying...' : 'Verify OTP'}
          </button>
          <p><a href="#" onClick={e => { e.preventDefault(); reset(); }}>Change number / Resend</a></p>
        </form>
      )}

      {error && <p style={{ color: 'red', fontSize: 14 }}>{error}</p>}
    </div>
  );
}

const styles = {
  card:      { maxWidth: 380, margin: '60px auto', padding: 32, border: '1px solid #eee', borderRadius: 12, fontFamily: 'sans-serif' },
  input:     { width: '100%', padding: 10, margin: '8px 0', border: '1px solid #ccc', borderRadius: 8, fontSize: 16, boxSizing: 'border-box' },
  btn:       { width: '100%', padding: 12, background: '#25D366', color: '#fff', border: 'none', borderRadius: 8, fontSize: 16, cursor: 'pointer', marginTop: 8 },
  checkmark: { fontSize: 48 },
};
```

**Usage in your app:**

```jsx
import WhatsAppLogin from './components/WhatsAppLogin';

function App() {
  function handleLoginSuccess(phone) {
    console.log('Verified phone:', phone);
    // Set your auth state, redirect, etc.
  }

  return <WhatsAppLogin onSuccess={handleLoginSuccess} />;
}
```

---

## Next.js Integration

This is the **recommended production pattern** — your API token stays on the server, never exposed to the browser.

### API Route Proxy

**`app/api/send-otp/route.js`** (App Router)

```js
import { NextResponse } from 'next/server';

const IFLORABUZZ_BASE  = process.env.IFLORABUZZ_API_BASE;   // server-only env var
const IFLORABUZZ_TOKEN = process.env.IFLORABUZZ_API_TOKEN;  // server-only env var
const TEMPLATE_NAME    = process.env.OTP_TEMPLATE_NAME;
const LANG_CODE        = process.env.OTP_LANG_CODE || 'en';

export async function POST(req) {
  const { phone } = await req.json();

  if (!phone || !/^\+\d{7,15}$/.test(phone)) {
    return NextResponse.json({ error: 'Invalid phone number' }, { status: 400 });
  }

  const res = await fetch(`${IFLORABUZZ_BASE}/send-otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${IFLORABUZZ_TOKEN}`,
    },
    body: JSON.stringify({ to: phone, templateName: TEMPLATE_NAME, languageCode: LANG_CODE }),
  });

  const data = await res.json();
  return NextResponse.json(data, { status: res.status });
}
```

**`app/api/verify-otp/route.js`**

```js
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { SignJWT } from 'jose';   // npm install jose

const IFLORABUZZ_BASE  = process.env.IFLORABUZZ_API_BASE;
const IFLORABUZZ_TOKEN = process.env.IFLORABUZZ_API_TOKEN;
const JWT_SECRET       = new TextEncoder().encode(process.env.JWT_SECRET);

export async function POST(req) {
  const { phone, otp } = await req.json();

  const res = await fetch(`${IFLORABUZZ_BASE}/verify-otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${IFLORABUZZ_TOKEN}`,
    },
    body: JSON.stringify({ to: phone, otp }),
  });

  const data = await res.json();
  if (!res.ok) return NextResponse.json(data, { status: res.status });

  // Issue your own session JWT
  const token = await new SignJWT({ phone })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('7d')
    .sign(JWT_SECRET);

  const response = NextResponse.json({ success: true });
  response.cookies.set('session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7,   // 7 days
    path: '/',
  });

  return response;
}
```

**`.env.local`**

```env
IFLORABUZZ_API_BASE=https://your-iflorabuzz-server.com
IFLORABUZZ_API_TOKEN=your_api_token_here
OTP_TEMPLATE_NAME=your_auth_template_name
OTP_LANG_CODE=en
JWT_SECRET=your_super_secret_jwt_key_min_32_chars
```

### Login Page Component

**`app/login/page.jsx`**

```jsx
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [step, setStep]   = useState('send');
  const [phone, setPhone] = useState('');
  const [otp, setOtp]     = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');

  async function handleSend(e) {
    e.preventDefault();
    setLoading(true); setError('');
    const res  = await fetch('/api/send-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone }),
    });
    const data = await res.json();
    setLoading(false);
    if (!res.ok) return setError(data.error);
    setStep('verify');
  }

  async function handleVerify(e) {
    e.preventDefault();
    setLoading(true); setError('');
    const res  = await fetch('/api/verify-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone, otp }),
    });
    const data = await res.json();
    setLoading(false);
    if (!res.ok) return setError(data.error);
    router.push('/dashboard');   // redirect after login
  }

  return (
    <main style={{ maxWidth: 400, margin: '80px auto', padding: '0 20px', fontFamily: 'sans-serif' }}>
      <h1>Sign in to demo.com</h1>

      {step === 'send' ? (
        <form onSubmit={handleSend}>
          <label>Your WhatsApp number</label>
          <input
            type="tel" value={phone} onChange={e => setPhone(e.target.value)}
            placeholder="+919876543210" required
            style={inputStyle}
          />
          <button type="submit" disabled={loading} style={btnStyle}>
            {loading ? 'Sending…' : 'Send OTP on WhatsApp'}
          </button>
        </form>
      ) : (
        <form onSubmit={handleVerify}>
          <p>OTP sent to <strong>{phone}</strong></p>
          <input
            type="number" value={otp} onChange={e => setOtp(e.target.value)}
            placeholder="Enter 6-digit OTP" maxLength={6} required
            style={{ ...inputStyle, textAlign: 'center', letterSpacing: 8, fontSize: 24 }}
          />
          <button type="submit" disabled={loading} style={btnStyle}>
            {loading ? 'Verifying…' : 'Verify & Login'}
          </button>
          <p><button type="button" onClick={() => { setStep('send'); setError(''); }} style={linkStyle}>
            ← Change number
          </button></p>
        </form>
      )}

      {error && <p style={{ color: 'red' }}>{error}</p>}
    </main>
  );
}

const inputStyle = { display: 'block', width: '100%', padding: 10, margin: '8px 0 16px', border: '1px solid #ccc', borderRadius: 8, fontSize: 16, boxSizing: 'border-box' };
const btnStyle   = { width: '100%', padding: 12, background: '#25D366', color: '#fff', border: 'none', borderRadius: 8, fontSize: 16, cursor: 'pointer' };
const linkStyle  = { background: 'none', border: 'none', color: '#0070f3', cursor: 'pointer', fontSize: 14, padding: 0 };
```

---

## Flutter Integration

### Repository Method

Add these methods to your repository or API service class:

**`lib/services/whatsapp_otp_service.dart`**

```dart
import 'package:dio/dio.dart';

class WhatsAppOtpService {
  final Dio _dio;

  // _dio should have baseUrl and Authorization header pre-configured
  WhatsAppOtpService(this._dio);

  /// Sends OTP to [phone] via the given AUTHENTICATION template.
  /// Returns true on success.
  Future<bool> sendOtp({
    required String phone,
    required String templateName,
    String languageCode = 'en',
  }) async {
    try {
      final res = await _dio.post('/send-otp', data: {
        'to': phone,
        'templateName': templateName,
        'languageCode': languageCode,
      });
      return res.statusCode == 200 && res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies [otp] for [phone].
  /// Returns null on success, or an error message string on failure.
  Future<String?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await _dio.post('/verify-otp', data: {'to': phone, 'otp': otp});
      if (res.statusCode == 200 && res.data['success'] == true) return null;
      return res.data['error'] ?? 'Verification failed';
    } on DioException catch (e) {
      return e.response?.data?['error'] ?? 'Verification failed';
    }
  }
}
```

### Login Screen

**`lib/screens/whatsapp_login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'whatsapp_otp_service.dart';

enum OtpStep { send, verify, verified }

class WhatsAppLoginScreen extends StatefulWidget {
  final WhatsAppOtpService service;
  final String templateName;
  final void Function(String phone) onVerified;

  const WhatsAppLoginScreen({
    super.key,
    required this.service,
    required this.templateName,
    required this.onVerified,
  });

  @override
  State<WhatsAppLoginScreen> createState() => _WhatsAppLoginScreenState();
}

class _WhatsAppLoginScreenState extends State<WhatsAppLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  OtpStep _step    = OtpStep.send;
  bool _loading    = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid number with country code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await widget.service.sendOtp(phone: phone, templateName: widget.templateName);
    setState(() {
      _loading = false;
      if (ok) _step = OtpStep.verify;
      else _error = 'Failed to send OTP. Check the number and try again.';
    });
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = null; });
    final err = await widget.service.verifyOtp(
      phone: _phoneCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
    );
    setState(() {
      _loading = false;
      if (err == null) {
        _step = OtpStep.verified;
        widget.onVerified(_phoneCtrl.text.trim());
      } else {
        _error = err;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login with WhatsApp')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step == OtpStep.send) ...[
                  const Text('Enter your WhatsApp number',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+919876543210',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton('Send OTP on WhatsApp', _sendOtp),
                ],

                if (_step == OtpStep.verify) ...[
                  Text('OTP sent to ${_phoneCtrl.text}',
                      style: const TextStyle(color: Colors.blue)),
                  const SizedBox(height: 16),
                  const Text('Enter OTP',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '------',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton('Verify OTP', _verifyOtp),
                  TextButton(
                    onPressed: () => setState(() { _step = OtpStep.send; _error = null; }),
                    child: const Text('Change number / Resend'),
                  ),
                ],

                if (_step == OtpStep.verified)
                  const Center(
                    child: Column(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 12),
                      Text('Verified!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
```

### Wiring It Up

```dart
// In your main app or router:
Navigator.push(context, MaterialPageRoute(
  builder: (_) => WhatsAppLoginScreen(
    service: WhatsAppOtpService(dio),   // your configured Dio instance
    templateName: 'your_auth_template_name',
    onVerified: (phone) {
      // Store session, navigate to home, etc.
      Navigator.pushReplacementNamed(context, '/home');
    },
  ),
));
```

---

## React Native Integration

**`src/services/whatsappOtp.js`**

```js
const API_BASE  = 'https://your-iflorabuzz-server.com';
const API_TOKEN = 'YOUR_API_TOKEN';   // store in react-native-config or expo-constants

export async function sendOtp(phone, templateName, languageCode = 'en') {
  const res = await fetch(`${API_BASE}/send-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_TOKEN}` },
    body: JSON.stringify({ to: phone, templateName, languageCode }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Failed to send OTP');
  return data;
}

export async function verifyOtp(phone, otp) {
  const res = await fetch(`${API_BASE}/verify-otp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_TOKEN}` },
    body: JSON.stringify({ to: phone, otp }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Verification failed');
  return data;
}
```

**`src/screens/WhatsAppLoginScreen.js`**

```jsx
import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ActivityIndicator, Alert } from 'react-native';
import { sendOtp, verifyOtp } from '../services/whatsappOtp';

const TEMPLATE = 'your_auth_template_name';

export default function WhatsAppLoginScreen({ navigation }) {
  const [step, setStep]   = useState('send');
  const [phone, setPhone] = useState('');
  const [otp, setOtp]     = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');

  async function handleSend() {
    if (!/^\+\d{7,15}$/.test(phone)) {
      return setError('Enter a valid number with country code (e.g. +919876543210)');
    }
    setLoading(true); setError('');
    try {
      await sendOtp(phone, TEMPLATE);
      setStep('verify');
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify() {
    if (otp.length !== 6) return setError('Enter the 6-digit OTP');
    setLoading(true); setError('');
    try {
      await verifyOtp(phone, otp);
      Alert.alert('Success', 'Phone verified!', [
        { text: 'OK', onPress: () => navigation.replace('Home') },
      ]);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Login with WhatsApp</Text>

      {step === 'send' ? (
        <>
          <TextInput
            style={styles.input}
            placeholder="+919876543210"
            keyboardType="phone-pad"
            value={phone}
            onChangeText={setPhone}
          />
          <TouchableOpacity style={styles.btn} onPress={handleSend} disabled={loading}>
            {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.btnText}>Send OTP on WhatsApp</Text>}
          </TouchableOpacity>
        </>
      ) : (
        <>
          <Text style={styles.info}>OTP sent to {phone}</Text>
          <TextInput
            style={[styles.input, styles.otpInput]}
            placeholder="------"
            keyboardType="number-pad"
            maxLength={6}
            value={otp}
            onChangeText={setOtp}
          />
          <TouchableOpacity style={styles.btn} onPress={handleVerify} disabled={loading}>
            {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.btnText}>Verify OTP</Text>}
          </TouchableOpacity>
          <TouchableOpacity onPress={() => { setStep('send'); setError(''); }}>
            <Text style={styles.link}>Change number / Resend</Text>
          </TouchableOpacity>
        </>
      )}

      {!!error && <Text style={styles.error}>{error}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#fff' },
  title:     { fontSize: 24, fontWeight: 'bold', marginBottom: 24 },
  input:     { borderWidth: 1, borderColor: '#ccc', borderRadius: 10, padding: 12, fontSize: 16, marginBottom: 16 },
  otpInput:  { textAlign: 'center', letterSpacing: 12, fontSize: 24, fontWeight: 'bold' },
  btn:       { backgroundColor: '#25D366', padding: 14, borderRadius: 10, alignItems: 'center', marginBottom: 12 },
  btnText:   { color: '#fff', fontSize: 16, fontWeight: '600' },
  link:      { color: '#0070f3', textAlign: 'center', marginTop: 8 },
  info:      { color: '#555', marginBottom: 12 },
  error:     { color: 'red', marginTop: 8, fontSize: 13 },
});
```

---

## Security Best Practices

### 1. Never expose your API token client-side

Always proxy through your own backend. The browser/app should call **your** server, which then calls the iFloraBuzz API.

```
Browser → your-server.com/api/send-otp → iFloraBuzz API
```

### 2. Rate limiting

Add rate limiting to your proxy endpoints to prevent OTP spam:

```js
// Express example using express-rate-limit
const rateLimit = require('express-rate-limit');

const otpLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,   // 10 minutes
  max: 5,                      // max 5 OTP requests per IP per window
  message: { error: 'Too many OTP requests. Please wait 10 minutes.' },
});

app.post('/api/send-otp', otpLimiter, async (req, res) => { /* ... */ });
```

### 3. Phone number validation

Always validate E.164 format before calling the API:

```js
function isValidPhone(phone) {
  return /^\+\d{7,15}$/.test(phone);
}
```

### 4. Session management after verification

After a successful `/verify-otp`, issue your own short-lived session token — don't rely on the OTP itself as a session credential:

```js
// Node.js / Express example
const jwt = require('jsonwebtoken');

app.post('/api/verify-otp', async (req, res) => {
  // ... call iFloraBuzz verify-otp ...
  if (verified) {
    const sessionToken = jwt.sign(
      { phone: req.body.phone, iat: Date.now() },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
    res.cookie('session', sessionToken, { httpOnly: true, secure: true, sameSite: 'lax' });
    res.json({ success: true });
  }
});
```

### 5. HTTPS only

Always serve your application over HTTPS. WhatsApp OTP flows over HTTPS by default, but your own endpoints must also be secured.

### 6. OTP expiry

The iFloraBuzz server automatically expires OTPs after **10 minutes**. Your UI should reflect this — show a countdown timer and a "Resend" option after expiry.

---

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `WhatsApp not configured` | Phone number ID or access token missing | Configure WhatsApp in iFloraBuzz Settings |
| `Failed to send OTP` | Template not approved or wrong name | Check template status in Meta Business Manager |
| `No OTP found for this number` | OTP expired or never sent | Call `/send-otp` again before verifying |
| `OTP has expired` | More than 10 minutes passed | Request a new OTP |
| `Incorrect OTP` | User entered wrong code | Let user retry (max 3 attempts recommended) |
| `401 Unauthorized` | Invalid or missing API token | Check `Authorization: Bearer <token>` header |
| Template not sending | Template category wrong | Must be `AUTHENTICATION` category, not `UTILITY` |
| OTP received but button missing | Template has no OTP button | Recreate template with a `COPY_CODE` OTP button |

### Testing Your Template

Before going live, use the built-in test tool in iFloraBuzz:

1. Go to **Templates**
2. Find your AUTHENTICATION template (must be APPROVED)
3. Click the **Test** button
4. Enter a phone number and click **Send OTP on WhatsApp**
5. Enter the received OTP and click **Verify OTP**

If verification succeeds, your template and API are correctly configured.

---

## Quick Reference

```
POST /send-otp
  Body: { to, templateName, languageCode }
  Auth: Bearer token
  Returns: { success: true, wamid }

POST /verify-otp
  Body: { to, otp }
  Auth: Bearer token
  Returns: { success: true, message }

OTP TTL: 10 minutes
OTP length: 6 digits
OTP reuse: single-use (deleted after successful verification)
Phone format: E.164 (e.g. +919876543210)
```

---

*For support, contact the iFloraBuzz team or raise an issue in the project repository.*
