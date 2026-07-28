# 🔔 Sendzyy — Notification Module: Detailed Research & Implementation Report

> **Project:** Sendzyy (WhatsApp Marketing Platform)
> **Stack:** Flutter (Web + Android + iOS) · Node.js/Express Backend · MongoDB · Socket.io
> **Date:** July 2026
> **Author:** Technical Research Report

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current System Architecture](#2-current-system-architecture)
3. [Push Notification Services — Full Comparison](#3-push-notification-services--full-comparison)
4. [🏆 Recommended Service: Firebase Cloud Messaging (FCM)](#4-recommended-service-firebase-cloud-messaging-fcm)
5. [Notification Trigger Modules — Complete List](#5-notification-trigger-modules--complete-list)
6. [In-App Notification Center Architecture](#6-in-app-notification-center-architecture)
7. [Technical Implementation Blueprint](#7-technical-implementation-blueprint)
8. [Database Schema Design](#8-database-schema-design)
9. [Backend Implementation Plan](#9-backend-implementation-plan)
10. [Flutter Client Implementation Plan](#10-flutter-client-implementation-plan)
11. [Web (PWA) Push Notification Setup](#11-web-pwa-push-notification-setup)
12. [Android Implementation](#12-android-implementation)
13. [iOS Implementation](#13-ios-implementation)
14. [Notification Payload Structures](#14-notification-payload-structures)
15. [Read / Dismiss & Badge Count System](#15-read--dismiss--badge-count-system)
16. [Security & Best Practices](#16-security--best-practices)
17. [Phased Implementation Roadmap](#17-phased-implementation-roadmap)
18. [Effort Estimate](#18-effort-estimate)

---

## 1. Executive Summary

Sendzyy is a multi-tenant WhatsApp Marketing Platform with a Flutter frontend (Web + Android + iOS) and a Node.js/Express backend using MongoDB + Socket.io.

**The goal** is to add a full-stack notification system that:
- Delivers **push notifications** even when the app/browser is **closed or backgrounded**
- Shows an **in-app Notification Center** with a **badge count** (e.g., "🔔 5,252")
- Supports **marking notifications as read** (click = dismiss from unread list)
- **Persists notifications** in the database per tenant/user
- Triggers notifications for all major platform events (chat, campaigns, payments, etc.)
- Works uniformly across **Web (PWA), Android, and iOS**

**Decision:** Firebase Cloud Messaging (FCM) is the **recommended** push notification provider (detailed justification in Section 4). The project already has a Firebase service account key (`serviceAccountKey.json`) with project ID `whatsapp-bulk-sender-9661e`, meaning Firebase is already partially set up.

---

## 2. Current System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Sendzyy Current State                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Flutter App (Web / Android / iOS)                                │
│  ├── Features: auth, chat, campaigns, templates, reports,         │
│  │             chatbot, leads, clients, settings, credits         │
│  └── Real-time: socket_io_client ^3.1.4                          │
│                                                                    │
│  Backend (Node.js / Express)                                      │
│  ├── Database: MongoDB (Mongoose)                                 │
│  ├── Real-time: Socket.io ^4.8.3                                  │
│  ├── Services: SocketEmitter, CampaignExecutor, MessageTracker   │
│  ├── Auth: JWT                                                    │
│  └── Firebase: serviceAccountKey.json already present ✅          │
│                                                                    │
│  Schemas Already Existing:                                        │
│  ├── Conversation (contactId, tenantId, lastMessage, hasReply)   │
│  ├── Message (text, isMe, messageType, wamid, status)            │
│  ├── Campaign (status, successCount, failureCount, phases)       │
│  ├── Lead (source, status, mobileNumber)                         │
│  ├── ScheduledCampaign (scheduledAt, status)                     │
│  └── Chatbot / ChatbotSession / ChatbotAnalytics                 │
│                                                                    │
│  ❌ MISSING: Push notification system                             │
│  ❌ MISSING: In-app notification center                           │
│  ❌ MISSING: FCM token registration & management                  │
└──────────────────────────────────────────────────────────────────┘
```

### Key Insight
The project already uses **Socket.io** for real-time updates (`SocketEmitter` service emits campaign progress events to tenant rooms). Push notifications will **complement** Socket.io:

- **Socket.io** → app is open (foreground real-time)
- **FCM/Push** → app is closed / backgrounded / browser tab is hidden

---

## 3. Push Notification Services — Full Comparison

### 3.1 Comparison Table

| Criteria | **Firebase FCM** | **OneSignal** | **Pusher Beams** | **AWS SNS** | **Airship (formerly Urban Airship)** | **Braze** |
|---|---|---|---|---|---|---|
| **Free Tier** | ✅ Unlimited (free forever) | ✅ 10,000 subscribers free | ✅ 1,000 devices free | ✅ 1M notifications/mo free | ❌ Paid only | ❌ Enterprise only |
| **Android Support** | ✅ Native (Google's own) | ✅ | ✅ | ✅ | ✅ | ✅ |
| **iOS Support** | ✅ via APNs bridge | ✅ | ✅ | ✅ via SNS | ✅ | ✅ |
| **Web/PWA Support** | ✅ Chrome, Firefox, Edge, Safari 16.1+ | ✅ | ✅ | ⚠️ Limited | ✅ | ✅ |
| **Background Delivery** | ✅ Full support | ✅ Full support | ✅ | ✅ | ✅ | ✅ |
| **Silent/Data Notifications** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Multi-tenant Support** | ✅ Topic-based / per-device token | ⚠️ Requires segments | ⚠️ Requires channels | ✅ Topic-based | ✅ | ✅ |
| **Flutter SDK** | ✅ `firebase_messaging` (official) | ✅ `onesignal_flutter` | ✅ `pusher_beams` | ⚠️ Manual | ✅ | ✅ |
| **Node.js SDK** | ✅ `firebase-admin` (official) | ✅ REST API | ✅ `@pusher/push-notifications-server` | ✅ `@aws-sdk/client-sns` | ✅ REST | ✅ REST |
| **Analytics / Delivery Reports** | ✅ (via Firebase Console) | ✅ Rich built-in analytics | ⚠️ Basic | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| **Topic/Group Messaging** | ✅ FCM Topics | ✅ Segments | ✅ Beams | ✅ Topics | ✅ | ✅ |
| **Message Priority (high/normal)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Already in Project** | ✅ **serviceAccountKey.json exists** | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Setup Complexity** | 🟢 Low | 🟡 Medium | 🟡 Medium | 🔴 High | 🔴 High | 🔴 High |
| **Cost (Scale)** | 🟢 Free forever | 🟡 Paid after threshold | 🟡 Paid after threshold | 🟡 Per-call cost | 🔴 Expensive | 🔴 Very expensive |
| **Vendor Lock-in** | 🟡 Medium (Google) | 🟡 Medium | 🟡 Medium | 🟢 Low | 🔴 High | 🔴 High |
| **Data Privacy** | 🟢 No notification data stored by Google | 🔴 Data stored on OneSignal servers | 🟡 Minimal | 🟢 Your AWS account | 🔴 Stored externally | 🔴 Stored externally |
| **Rate Limits** | None (practical) | 10K/day free | 1K/day free | None (practical) | None | None |
| **Offline Queuing** | ✅ Auto-retry by platform | ✅ | ✅ | ✅ | ✅ | ✅ |

### 3.2 Detailed Per-Service Analysis

#### 🔵 Firebase Cloud Messaging (FCM) — Google

**Pros:**
- Completely **free** with no hard limits (Google does not charge for FCM)
- Official `firebase_messaging` Flutter plugin with best-in-class documentation
- `firebase-admin` Node.js SDK — already installable since serviceAccountKey.json is present
- Handles Android, iOS (via APNs), and Web (VAPID) from **one unified API**
- Background message delivery via dedicated FCM background handlers
- Supports **data-only (silent)** notifications that don't show UI but trigger Flutter code
- FCM Topics allow broadcast to all devices of a tenant without storing token lists client-side
- Battle-tested by billions of devices worldwide

**Cons:**
- Google dependency (not ideal for privacy-critical EU deployments without care)
- Requires Google Services JSON / GoogleService-Info.plist for native apps
- Web needs Service Worker setup

---

#### 🟠 OneSignal

**Pros:**
- Excellent dashboard/analytics
- Easy A/B testing and scheduling
- REST API very simple to call

**Cons:**
- All notification payloads pass through OneSignal's servers (data privacy concern for a marketing platform)
- Free tier limited to 10,000 subscribers → would cost for large Sendzyy deployments
- Less control over delivery behavior vs. FCM

---

#### 🟣 Pusher Beams

**Pros:**
- Simple API, Pusher ecosystem integration

**Cons:**
- Very small free tier (1,000 devices)
- No advanced analytics
- Less community support for Flutter

---

#### 🟡 AWS SNS

**Pros:**
- Already in AWS ecosystem (if other AWS services used)
- Very scalable

**Cons:**
- No unified SDK — must manage APNs + FCM + Web separately
- Much higher setup complexity
- Pricing model more complex

---

#### ⚫ Airship / Braze

- Enterprise-grade tools with rich features but **very high cost** — not suitable for a SaaS marketing tool at early/growth stage

---

## 4. 🏆 Recommended Service: Firebase Cloud Messaging (FCM)

### Verdict: **Firebase Cloud Messaging (FCM)** ✅

**Reasons:**

1. **Already Set Up**: `serviceAccountKey.json` with project ID `whatsapp-bulk-sender-9661e` is already in the backend directory. This means the Firebase project exists and the service account is ready.

2. **Zero Cost**: FCM is free forever with no notification limits — ideal for a multi-tenant WhatsApp marketing SaaS.

3. **Single SDK for All Platforms**: One `firebase_messaging` Flutter package handles Android push, iOS push, and Web push — reducing maintenance burden significantly.

4. **Best Background Support**: FCM has first-class background message handling for Flutter (`FirebaseMessaging.onBackgroundMessage`) — works even when the app process is killed.

5. **Data Privacy**: Unlike OneSignal, notification payloads are only passed through Google's infrastructure transiently. No notification content is stored by FCM on Google servers.

6. **Topics for Multi-tenancy**: FCM Topics let you subscribe each device to `tenant_{tenantId}` so you can broadcast to all a tenant's devices in one API call — perfect for Sendzyy's multi-tenant model.

7. **Web Service Worker Support**: FCM supports PWA/Web with the Firebase JS SDK and a service worker, which Sendzyy needs since it runs on Web.

8. **Node.js `firebase-admin` SDK**: Integrates directly into the existing Express server.

---

## 5. Notification Trigger Modules — Complete List

Based on the Sendzyy codebase analysis, here are **all events that should trigger notifications**, modeled after WhatsApp-style notification behavior:

### 5.1 💬 Chat / Inbox Notifications (HIGHEST PRIORITY — Like WhatsApp)

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| C1 | **New inbound message received** | `📩 {ContactName}` | `{lastMessageText}` (truncated to 80 chars) | Any new inbound WhatsApp message (`isMe: false`) |
| C2 | **New media message received** | `📷 {ContactName}` | `"Sent you a photo/video/document"` | `messageType = image/video/document` |
| C3 | **New voice note received** | `🎤 {ContactName}` | `"Sent you a voice message"` | `messageType = voice/audio` |
| C4 | **Message delivery status: Read** | (silent data notification) | — | `status = read` on outbound message (for analytics refresh) |
| C5 | **Unread conversation count changed** | (badge update) | — | Any new inbound message |

**Example payload (C1):**
```json
{
  "title": "📩 Rajan Sharma",
  "body": "Hello! I'd like to know more about your product",
  "data": {
    "type": "new_message",
    "contactId": "919876543210",
    "conversationId": "conv_abc123",
    "tenantId": "tenant_xyz"
  }
}
```

---

### 5.2 📣 Campaign Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| K1 | **Campaign completed** | `✅ Campaign Completed` | `"{CampaignName}" sent to {N} contacts. Success: {X}` | `campaign.status = completed` |
| K2 | **Campaign failed/error** | `❌ Campaign Failed` | `"{CampaignName}" encountered an error. Tap to view details.` | `campaign.status = error` |
| K3 | **Campaign retry phase started** | `🔄 Retry Phase {N} Started` | `"Retrying {CampaignName}" — Phase {N} of {Total}` | `phase:started` event |
| K4 | **Campaign retry phase completed** | `✅ Retry Phase {N} Done` | `"Phase {N} complete: {Success} sent, {Fail} failed"` | `phase:completed` event |
| K5 | **Scheduled campaign about to start** | `⏰ Campaign Starting Soon` | `"{CampaignName}" starts in 30 minutes` | 30 min before `scheduledAt` |
| K6 | **Campaign significant milestone** | `📊 Campaign Update` | `{N} of {Total} messages sent` | At 25%, 50%, 75%, 100% milestones |

---

### 5.3 💳 Credits & Payment Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| P1 | **Payment successful** | `💳 Payment Successful` | `Plan activated! Your account is valid till {Date}` | Razorpay payment verified |
| P2 | **Low credit balance warning** | `⚠️ Low Credits` | `You have {N} credits remaining. Top up to avoid interruptions.` | Credits fall below threshold |
| P3 | **Credit balance added** | `✨ Credits Added` | `{N} credits have been added to your account` | Credit purchase confirmed |
| P4 | **Subscription expiry warning (7 days)** | `⏳ Subscription Expiring Soon` | `Your plan expires in 7 days. Renew now to continue.` | 7 days before `expiryDate` |
| P5 | **Subscription expired** | `🚫 Subscription Expired` | `Your Sendzyy subscription has expired. Renew to continue.` | On `expiryDate` |

---

### 5.4 🤖 Chatbot Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| B1 | **Chatbot session ended / user dropped** | `📉 Chatbot Drop` | `"{BotName}": A user dropped off at step "{NodeName}"` | `droppedSessions` count increases |
| B2 | **Chatbot daily analytics summary** | `📊 Chatbot Daily Report` | `"{BotName}": {Sessions} sessions, {Completed} completed today` | Daily cron at 8 AM |
| B3 | **Chatbot trigger activated** | `🤖 Chatbot Triggered` | `"{BotName}" started for {ContactName}` | New chatbot session created |

---

### 5.5 🧲 Lead Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| L1 | **New lead arrived (Shopify/WordPress)** | `🛒 New Lead!` | `{Name} from {Source} — {FormName}` | New lead document created |
| L2 | **Lead auto-message sent** | `✉️ Lead Messaged` | `WhatsApp sent to {Name} ({MobileNumber})` | Lead trigger executed successfully |
| L3 | **Lead auto-message failed** | `⚠️ Lead Message Failed` | `Could not message {Name}. Tap to review.` | Lead trigger execution error |

---

### 5.6 📅 Scheduled Message Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| S1 | **Scheduled campaign executed** | `✅ Scheduled Campaign Sent` | `"{CampaignName}" was sent to {N} contacts` | Scheduler fires and executes |
| S2 | **Scheduled campaign failed** | `❌ Scheduled Campaign Failed` | `"{CampaignName}" could not be sent. Tap to review.` | Scheduler execution error |

---

### 5.7 ⚙️ WhatsApp Account & System Notifications

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| W1 | **WhatsApp token expiring soon** | `🔑 Token Expiring` | `Your WhatsApp access token expires in {N} days. Update it now.` | `tokenStatus = expiring_soon` |
| W2 | **WhatsApp token expired** | `🚨 Token Expired` | `Your WhatsApp access token has expired. Messages cannot be sent.` | `tokenStatus = expired` |
| W3 | **Phone number quality rating changed** | `📉 Quality Rating Changed` | `Your number quality rating changed to {YELLOW/RED}. Review campaigns.` | Webhook event from Meta |
| W4 | **Template approved** | `✅ Template Approved` | `"{TemplateName}" has been approved by WhatsApp` | Meta webhook `APPROVED` status |
| W5 | **Template rejected** | `❌ Template Rejected` | `"{TemplateName}" was rejected. Reason: {Reason}` | Meta webhook rejection |

---

### 5.8 🔧 Admin/System Notifications (for Super-admin)

| # | Event | Notification Title | Notification Body | Trigger Condition |
|---|---|---|---|---|
| A1 | **New tenant registered** | `👤 New Sign-Up` | `{Name} ({Email}) joined Sendzyy` | New tenant document created |
| A2 | **Tenant payment received** | `💰 Payment Received` | `{Name} paid ₹{Amount} for {PlanName}` | Payment verified for any tenant |

---

## 6. In-App Notification Center Architecture

### 6.1 UI Design Spec

```
┌─────────────────────────────────────────────────────┐
│  Sendzyy Dashboard                    🔔 52  ▼      │
│  ──────────────────────────────────────────────────  │
│  ┌─────────────────────────────────────────────────┐ │
│  │  Notifications                    Mark All Read │ │
│  │  ─────────────────────────────────────────────  │ │
│  │  🟢 ● 📩 Rajan Sharma           2 min ago      │ │
│  │        "Hello! I'd like to know..."             │ │
│  │  ─────────────────────────────────────────────  │ │
│  │  🟢 ● ✅ Campaign Completed       5 min ago      │ │
│  │        "Summer Sale" sent to 1,240 contacts     │ │
│  │  ─────────────────────────────────────────────  │ │
│  │  🟢 ● 🛒 New Lead!               1 hr ago       │ │
│  │        Priya from Shopify — Contact Form        │ │
│  │  ─────────────────────────────────────────────  │ │
│  │  ⚪   💳 Payment Successful       Yesterday      │ │
│  │        Plan activated till Dec 31, 2026         │ │
│  │  ─────────────────────────────────────────────  │ │
│  │  [ Load More... ]                               │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 6.2 Notification Center Features

| Feature | Description |
|---|---|
| **Unread badge count** | Red circular badge on bell icon showing total unread count (e.g., "52") |
| **Notification list** | Sorted by `createdAt` descending, newest first |
| **Unread indicator** | Blue dot `●` on left of unread notifications |
| **Click to read** | Clicking any notification marks it as `read`, removes blue dot, decrements count |
| **"Mark All as Read"** | Single button marks all as read, resets badge count to 0 |
| **Load more / pagination** | First 20 loaded, "Load More" button fetches next page |
| **Deep linking** | Tapping a notification navigates to relevant screen (e.g., chat page for message notification) |
| **Notification categories** | Filter tabs: All | Chat | Campaigns | Payments | System |
| **Timestamps** | Human-readable relative times ("2 min ago", "Yesterday") |
| **Delete notification** | Swipe-to-delete (mobile) / X button (web) |

---

## 7. Technical Implementation Blueprint

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SENDZYY NOTIFICATION ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────┐       ┌──────────────────────────────────────┐  │
│  │   Flutter Client     │       │          Node.js Backend             │  │
│  │                      │       │                                      │  │
│  │  NotificationBloc   ◄──────►│  /api/notifications/* (REST)         │  │
│  │  NotificationRepo   │  HTTP │  - GET list (paginated)              │  │
│  │  FCM Token Reg.     │       │  - PATCH mark-read                   │  │
│  │  Badge Count UI     │       │  - DELETE notification               │  │
│  │                      │       │  - GET unread count                  │  │
│  │  Socket.io client   ◄──────►│  - POST register FCM token           │  │
│  │  (foreground events) │  WS  │                                      │  │
│  │                      │       │  Socket.io (foreground push):        │  │
│  │  FCM Background     ◄──────►│  - notification:new → broadcast      │  │
│  │  Handler             │  FCM │  - notification:count_update         │  │
│  └─────────────────────┘       │                                      │  │
│                                 │  FCMService.js (background push):    │  │
│  ┌───────────────────┐          │  - sendToDevice(fcmToken, payload)  │  │
│  │   Web (PWA)        │          │  - sendToTopic(tenantId, payload)   │  │
│  │  Service Worker   ◄─────────►│  - sendMulticast(tokens, payload)   │  │
│  │  Push Notification│  FCM     │                                      │  │
│  └───────────────────┘          │  NotificationService.js:            │  │
│                                 │  - createNotification()              │  │
│                                 │  - getUnreadCount()                  │  │
│                                 │  - markRead() / markAllRead()        │  │
│                                 │  - getTokensByTenant()               │  │
│                                 │                                      │  │
│                                 │  MongoDB Collections:                │  │
│                                 │  - notifications (per-tenant log)    │  │
│                                 │  - fcm_tokens (device registration)  │  │
│                                 └──────────────────────────────────────┘  │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     Firebase Cloud Messaging                          │  │
│  │   FCM HTTP v1 API ──── firebase-admin (Node.js) ──► Device FCM      │  │
│  │   Project: whatsapp-bulk-sender-9661e (already configured ✅)        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Database Schema Design

### 8.1 Notification Schema (MongoDB)

```javascript
const notificationSchema = new mongoose.Schema({
    // Targeting
    tenantId: { type: String, required: true, index: true },
    userId:   { type: String, default: null },     // null = all users of tenant

    // Content
    title:   { type: String, required: true },
    body:    { type: String, required: true },
    icon:    { type: String, default: null },       // URL for custom icon
    imageUrl:{ type: String, default: null },       // Rich notification image

    // Classification
    type: {
        type: String,
        required: true,
        enum: [
            'new_message',       // Chat: new inbound WhatsApp message
            'campaign_completed',
            'campaign_failed',
            'campaign_retry',
            'scheduled_campaign',
            'payment_success',
            'payment_failed',
            'low_credits',
            'subscription_expiry',
            'new_lead',
            'chatbot_session',
            'chatbot_analytics',
            'template_approved',
            'template_rejected',
            'token_expiry',
            'quality_rating',
            'new_tenant',        // Admin only
            'system',
        ]
    },
    category: {
        type: String,
        enum: ['chat', 'campaign', 'payment', 'lead', 'chatbot', 'system', 'admin'],
        required: true
    },

    // Deep link data
    actionData: {
        type: mongoose.Schema.Types.Mixed,
        default: {}
        // Examples:
        // { screen: 'chat', contactId: '919876543210' }
        // { screen: 'campaign_detail', campaignId: 'camp_123' }
        // { screen: 'payments' }
        // { screen: 'leads', leadId: 'lead_abc' }
    },

    // State
    isRead:     { type: Boolean, default: false, index: true },
    readAt:     { type: Date, default: null },
    isDeleted:  { type: Boolean, default: false },

    // FCM delivery tracking
    fcmMessageId:  { type: String, default: null },
    deliveredAt:   { type: Date, default: null },
    pushSent:      { type: Boolean, default: false },

}, { timestamps: true });

// Compound indexes for performance
notificationSchema.index({ tenantId: 1, createdAt: -1 });
notificationSchema.index({ tenantId: 1, isRead: 1, isDeleted: 1 });
notificationSchema.index({ tenantId: 1, category: 1, createdAt: -1 });

// TTL: Auto-delete notifications older than 90 days
notificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 7776000 });

const Notification = mongoose.model('Notification', notificationSchema);
```

### 8.2 FCM Token Schema (MongoDB)

```javascript
const fcmTokenSchema = new mongoose.Schema({
    tenantId: { type: String, required: true, index: true },
    userId:   { type: String, default: null },

    // Device info
    token:    { type: String, required: true },
    platform: { type: String, enum: ['android', 'ios', 'web'], required: true },
    deviceId: { type: String, default: null },        // Unique device fingerprint
    deviceName: { type: String, default: null },      // "Pixel 7 Pro", "Safari on Mac"
    appVersion: { type: String, default: null },

    // Token health
    isActive:       { type: Boolean, default: true },
    lastUsedAt:     { type: Date, default: Date.now },
    registeredAt:   { type: Date, default: Date.now },
    invalidatedAt:  { type: Date, default: null },    // Set when FCM returns InvalidRegistration

    // FCM Topic subscriptions
    subscribedTopics: { type: [String], default: [] },
    // e.g. ['tenant_abc123', 'tenant_abc123_chat', 'tenant_abc123_campaigns']

}, { timestamps: true });

fcmTokenSchema.index({ tenantId: 1, isActive: 1 });
fcmTokenSchema.index({ token: 1 }, { unique: true });

const FCMToken = mongoose.model('FCMToken', fcmTokenSchema);
```

---

## 9. Backend Implementation Plan

### 9.1 Install Firebase Admin SDK

```bash
# In /backend directory
npm install firebase-admin
```

### 9.2 FCMService.js

```javascript
// /backend/services/FCMService.js
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize (only once)
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const messaging = admin.messaging();

const FCMService = {

    /**
     * Send push notification to a single FCM token (one device)
     */
    async sendToDevice(token, { title, body, data = {}, imageUrl = null }) {
        const message = {
            token,
            notification: { title, body, imageUrl },
            data: Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v)])
            ),
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'sendzyy_notifications',
                    imageUrl
                }
            },
            apns: {
                headers: { 'apns-priority': '10' },
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        contentAvailable: true
                    }
                }
            },
            webpush: {
                headers: { Urgency: 'high' },
                notification: { title, body, icon: '/icons/icon-192.png', image: imageUrl },
                fcmOptions: { link: data.link || '/' }
            }
        };

        try {
            const response = await messaging.send(message);
            return { success: true, messageId: response };
        } catch (error) {
            if (error.code === 'messaging/registration-token-not-registered') {
                return { success: false, invalidToken: true, error: error.message };
            }
            throw error;
        }
    },

    /**
     * Send to all devices of a tenant (using FCM Topic)
     * Topic naming: tenant_{tenantId}
     */
    async sendToTenant(tenantId, payload) {
        const topic = `tenant_${tenantId}`;
        return this.sendToTopic(topic, payload);
    },

    /**
     * Send to a specific FCM topic
     */
    async sendToTopic(topic, { title, body, data = {}, imageUrl = null }) {
        const message = {
            topic,
            notification: { title, body },
            data: Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v)])
            ),
            android: { priority: 'high', notification: { sound: 'default', channelId: 'sendzyy_notifications' } },
            apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default', contentAvailable: true } } },
            webpush: { headers: { Urgency: 'high' }, notification: { title, body, icon: '/icons/icon-192.png' } }
        };
        return messaging.send(message);
    },

    /**
     * Send to multiple tokens (batch, up to 500)
     */
    async sendMulticast(tokens, payload) {
        if (!tokens.length) return;
        const chunks = [];
        for (let i = 0; i < tokens.length; i += 500) {
            chunks.push(tokens.slice(i, i + 500));
        }
        const results = [];
        for (const chunk of chunks) {
            const message = { ...payload, tokens: chunk };
            const result = await messaging.sendEachForMulticast(message);
            results.push(result);
            // Identify and clean up invalid tokens
            result.responses.forEach((resp, idx) => {
                if (!resp.success && resp.error?.code === 'messaging/registration-token-not-registered') {
                    results.invalidTokens = results.invalidTokens || [];
                    results.invalidTokens.push(chunk[idx]);
                }
            });
        }
        return results;
    },

    /**
     * Subscribe device token to FCM topic
     */
    async subscribeToTopic(tokens, topic) {
        return messaging.subscribeToTopic(tokens, topic);
    },

    /**
     * Unsubscribe device token from FCM topic
     */
    async unsubscribeFromTopic(tokens, topic) {
        return messaging.unsubscribeFromTopic(tokens, topic);
    }
};

module.exports = FCMService;
```

### 9.3 NotificationService.js

```javascript
// /backend/services/NotificationService.js
const FCMService = require('./FCMService');
// Mongoose models: Notification, FCMToken (add to server.js schemas)

const NotificationService = {

    /**
     * Core method: Create notification in DB + send push
     */
    async create({ tenantId, title, body, type, category, actionData = {}, imageUrl = null }) {
        // 1. Save to MongoDB
        const notification = new Notification({
            tenantId, title, body, type, category, actionData, imageUrl
        });
        await notification.save();

        // 2. Get active FCM tokens for this tenant
        const tokens = await FCMToken.find({ tenantId, isActive: true }).select('token platform');

        // 3. Send push notification via FCM
        if (tokens.length > 0) {
            const tokenStrings = tokens.map(t => t.token);
            try {
                await FCMService.sendToTenant(tenantId, {
                    title, body, imageUrl,
                    data: {
                        notificationId: notification._id.toString(),
                        type,
                        category,
                        ...Object.fromEntries(
                            Object.entries(actionData).map(([k, v]) => [k, String(v)])
                        )
                    }
                });
                notification.pushSent = true;
                notification.deliveredAt = new Date();
                await notification.save();
            } catch (err) {
                console.error('[NotificationService] Push failed:', err.message);
            }
        }

        // 4. Emit via Socket.io (for foreground update)
        // SocketEmitter.emitNotification(tenantId, notification);

        return notification;
    },

    /**
     * Get notifications for a tenant (paginated)
     */
    async getForTenant(tenantId, { page = 1, limit = 20, category = null, unreadOnly = false }) {
        const query = { tenantId, isDeleted: false };
        if (category) query.category = category;
        if (unreadOnly) query.isRead = false;

        const [notifications, total, unreadCount] = await Promise.all([
            Notification.find(query)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(limit)
                .lean(),
            Notification.countDocuments(query),
            Notification.countDocuments({ tenantId, isRead: false, isDeleted: false })
        ]);

        return { notifications, total, unreadCount, page, pages: Math.ceil(total / limit) };
    },

    /**
     * Get unread count only (for badge)
     */
    async getUnreadCount(tenantId) {
        return Notification.countDocuments({ tenantId, isRead: false, isDeleted: false });
    },

    /**
     * Mark single notification as read
     */
    async markRead(notificationId, tenantId) {
        const result = await Notification.findOneAndUpdate(
            { _id: notificationId, tenantId },
            { isRead: true, readAt: new Date() },
            { new: true }
        );
        return result;
    },

    /**
     * Mark all as read for a tenant
     */
    async markAllRead(tenantId) {
        return Notification.updateMany(
            { tenantId, isRead: false },
            { isRead: true, readAt: new Date() }
        );
    },

    /**
     * Soft-delete a notification
     */
    async delete(notificationId, tenantId) {
        return Notification.findOneAndUpdate(
            { _id: notificationId, tenantId },
            { isDeleted: true }
        );
    }
};

module.exports = NotificationService;
```

### 9.4 REST API Endpoints

```
POST   /api/notifications/register-token    → Register/update FCM device token
GET    /api/notifications                   → Get notifications (paginated)
GET    /api/notifications/count             → Get unread count only (for badge)
PATCH  /api/notifications/:id/read         → Mark single notification as read
PATCH  /api/notifications/mark-all-read    → Mark all as read
DELETE /api/notifications/:id              → Delete single notification
DELETE /api/notifications/clear-all        → Clear all read notifications
```

### 9.5 Integration Points in server.js

Add notification triggers at these existing code locations:

```javascript
// ── CHAT: When new inbound message arrives (webhook handler) ──
// After saving Message document where isMe = false:
await NotificationService.create({
    tenantId,
    title: `📩 ${contactName}`,
    body: messageText.length > 80 ? messageText.slice(0, 77) + '...' : messageText,
    type: 'new_message',
    category: 'chat',
    actionData: { screen: 'chat', contactId }
});

// ── CAMPAIGN: After campaign completes ──
await NotificationService.create({
    tenantId,
    title: '✅ Campaign Completed',
    body: `"${campaignName}" sent to ${totalCount} contacts. Success: ${successCount}`,
    type: 'campaign_completed',
    category: 'campaign',
    actionData: { screen: 'campaign_detail', campaignId }
});

// ── LEAD: When new lead arrives ──
await NotificationService.create({
    tenantId,
    title: '🛒 New Lead!',
    body: `${lead.name} from ${lead.source} — ${lead.formName}`,
    type: 'new_lead',
    category: 'lead',
    actionData: { screen: 'leads', leadId: lead._id.toString() }
});

// ── PAYMENT: After Razorpay verification ──
await NotificationService.create({
    tenantId,
    title: '💳 Payment Successful',
    body: `Plan activated! Your account is valid till ${expiryDate.toLocaleDateString()}`,
    type: 'payment_success',
    category: 'payment',
    actionData: { screen: 'payments' }
});
```

---

## 10. Flutter Client Implementation Plan

### 10.1 New Dependencies (pubspec.yaml)

```yaml
dependencies:
  # Firebase
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3

  # Notification display (local notifications for foreground)
  flutter_local_notifications: ^17.2.3

  # Badge count (optional - for app icon badge)
  flutter_app_badger: ^1.5.0
```

### 10.2 Project Structure

```
lib/
└── features/
    └── notifications/
        ├── data/
        │   ├── models/
        │   │   ├── notification_model.dart
        │   │   └── notification_count_model.dart
        │   ├── repositories/
        │   │   └── notification_repository.dart
        │   └── datasources/
        │       ├── notification_remote_datasource.dart
        │       └── fcm_service.dart
        └── presentation/
            ├── bloc/
            │   ├── notification_bloc.dart
            │   ├── notification_event.dart
            │   └── notification_state.dart
            ├── pages/
            │   └── notifications_page.dart
            └── widgets/
                ├── notification_bell_icon.dart  (with badge count)
                ├── notification_list_item.dart
                └── notification_empty_state.dart
```

### 10.3 FCM Service (Flutter)

```dart
// lib/features/notifications/data/datasources/fcm_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    // Show local notification when app is in background/terminated
    await FCMService.showLocalNotification(message);
}

class FCMService {
    static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
    static final FlutterLocalNotificationsPlugin _localNotifications =
        FlutterLocalNotificationsPlugin();

    static Future<void> initialize() async {
        // Request permissions
        await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
        );

        // Setup local notifications for foreground
        await _initLocalNotifications();

        // Get FCM token and register with backend
        final token = await _messaging.getToken(
            vapidKey: 'YOUR_VAPID_KEY', // Web only
        );
        if (token != null) {
            await _registerTokenWithBackend(token);
        }

        // Token refresh
        _messaging.onTokenRefresh.listen(_registerTokenWithBackend);

        // Foreground message handler
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // When app opened from notification (background → foreground)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // When app opened from terminated state
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
            _handleNotificationTap(initialMessage);
        }
    }

    static Future<void> _handleForegroundMessage(RemoteMessage message) async {
        // Show local notification popup in foreground
        await showLocalNotification(message);
        // Also refresh in-app notification count via BLoC
    }

    static void _handleNotificationTap(RemoteMessage message) {
        // Navigate based on data payload
        final data = message.data;
        final screen = data['screen'];
        // Use navigator/router to deep-link
        switch (screen) {
            case 'chat':
                // Navigate to chat screen with contactId
                break;
            case 'campaign_detail':
                // Navigate to campaign detail
                break;
            // ...etc
        }
    }

    static Future<void> showLocalNotification(RemoteMessage message) async {
        // Platform-specific channel setup
        const androidDetails = AndroidNotificationDetails(
            'sendzyy_notifications',
            'Sendzyy Notifications',
            channelDescription: 'All Sendzyy platform notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
        );
        const iosDetails = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
        );

        await _localNotifications.show(
            message.hashCode,
            message.notification?.title,
            message.notification?.body,
            const NotificationDetails(android: androidDetails, iOS: iosDetails),
            payload: jsonEncode(message.data),
        );
    }

    static Future<void> _registerTokenWithBackend(String token) async {
        // POST /api/notifications/register-token
        // { token, platform: 'android'|'ios'|'web', deviceId }
    }
}
```

### 10.4 Notification Bell Widget (with badge count)

```dart
// lib/features/notifications/presentation/widgets/notification_bell_icon.dart

class NotificationBellIcon extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
                final count = state.unreadCount;
                return Stack(
                    children: [
                        IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () => Navigator.pushNamed(context, '/notifications'),
                        ),
                        if (count > 0)
                            Positioned(
                                right: 4, top: 4,
                                child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    child: Text(
                                        count > 999 ? '999+' : count.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                    ),
                                ),
                            ),
                    ],
                );
            },
        );
    }
}
```

---

## 11. Web (PWA) Push Notification Setup

### 11.1 Firebase Web Setup

```javascript
// web/firebase-messaging-sw.js (Service Worker)
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "YOUR_WEB_API_KEY",
    authDomain: "whatsapp-bulk-sender-9661e.firebaseapp.com",
    projectId: "whatsapp-bulk-sender-9661e",
    storageBucket: "whatsapp-bulk-sender-9661e.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    const { title, body, icon } = payload.notification;
    self.registration.showNotification(title, {
        body,
        icon: icon || '/icons/icon-192.png',
        badge: '/icons/badge-72.png',
        data: payload.data,
        actions: [
            { action: 'open', title: 'Open Sendzyy' },
            { action: 'dismiss', title: 'Dismiss' }
        ]
    });
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    if (event.action === 'open' || !event.action) {
        const data = event.notification.data;
        const url = buildDeepLinkUrl(data);
        event.waitUntil(clients.openWindow(url));
    }
});
```

### 11.2 VAPID Key Setup

In Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → Generate key pair (VAPID key). This is needed for web push.

---

## 12. Android Implementation

### 12.1 google-services.json

Download from Firebase Console and place at `android/app/google-services.json`

### 12.2 AndroidManifest.xml additions

```xml
<!-- Notification channel for Android 8+ -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="sendzyy_notifications" />

<!-- Default notification icon -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />

<!-- Default notification color -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```

### 12.3 Create Notification Channel (MainActivity.kt)

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            "sendzyy_notifications",
            "Sendzyy Notifications",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "All Sendzyy platform notifications"
            enableLights(true)
            enableVibration(true)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
```

### 12.4 Background Message Handler (main.dart)

```dart
void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Register background handler BEFORE runApp
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    runApp(const SendzyyApp());
}
```

---

## 13. iOS Implementation

### 13.1 GoogleService-Info.plist

Download from Firebase Console and place at `ios/Runner/GoogleService-Info.plist`

### 13.2 Capabilities Required (Xcode)

- ✅ Push Notifications
- ✅ Background Modes → Remote notifications

### 13.3 AppDelegate.swift

```swift
import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Request permission
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in print("iOS notification permission: \(granted)") }

        application.registerForRemoteNotifications()
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Called when APNs token is received — FCM will exchange for FCM token
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        // Send to backend
    }
}
```

### 13.4 iOS Background Processing

iOS requires special handling for background notifications. Add to Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
    <string>processing</string>
</array>
```

> **⚠️ Important iOS Note:** iOS has stricter APNs requirements. A valid Apple Developer account with Push Notifications enabled, and either APNs Authentication Key (.p8) or APNs Certificate (.p12) must be uploaded to Firebase Console for iOS push to work.

---

## 14. Notification Payload Structures

### 14.1 Standard Push Notification Payload

```json
{
    "notification": {
        "title": "📩 Rajan Sharma",
        "body": "Hello! I'd like to know more about your Sendzyy offer",
        "imageUrl": null
    },
    "data": {
        "notificationId": "68abc123def456",
        "type": "new_message",
        "category": "chat",
        "screen": "chat",
        "contactId": "919876543210",
        "tenantId": "tenant_xyz789",
        "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "android": {
        "priority": "high",
        "notification": {
            "channelId": "sendzyy_notifications",
            "sound": "default"
        }
    },
    "apns": {
        "headers": { "apns-priority": "10" },
        "payload": {
            "aps": {
                "sound": "default",
                "badge": 5,
                "content-available": 1,
                "mutable-content": 1
            }
        }
    },
    "webpush": {
        "headers": { "Urgency": "high" },
        "notification": {
            "icon": "/icons/icon-192.png",
            "badge": "/icons/badge-72.png",
            "vibrate": [200, 100, 200]
        }
    }
}
```

### 14.2 Silent Data-Only Notification (for badge refresh)

```json
{
    "data": {
        "type": "badge_update",
        "unreadCount": "52"
    },
    "android": { "priority": "high" },
    "apns": { "payload": { "aps": { "content-available": 1 } } }
}
```

---

## 15. Read / Dismiss & Badge Count System

### 15.1 Read Flow

```
User taps notification in Notification Center
              │
              ▼
NotificationBloc.add(MarkNotificationRead(id))
              │
              ▼
PATCH /api/notifications/:id/read
              │
              ▼
Backend: { isRead: true, readAt: new Date() }
              │
              ▼
Return updated unreadCount
              │
              ▼
NotificationBloc updates state → badge re-renders
```

### 15.2 Mark All Read Flow

```
User taps "Mark All as Read"
              │
              ▼
NotificationBloc.add(MarkAllRead())
              │
              ▼
PATCH /api/notifications/mark-all-read
              │
              ▼
Backend: updateMany({ tenantId, isRead: false }, { isRead: true })
              │
              ▼
Badge count → 0
```

### 15.3 Real-time Badge Update via Socket.io

When a new notification is created by the backend, emit to the tenant's Socket.io room:

```javascript
// In NotificationService.create(), after saving notification:
if (_io) {
    _io.to(tenantId).emit('notification:new', {
        notification: notification.toObject(),
        unreadCount: await Notification.countDocuments({ tenantId, isRead: false })
    });
}
```

Flutter Socket.io listener:

```dart
socket.on('notification:new', (data) {
    notificationBloc.add(NewNotificationReceived(
        notification: NotificationModel.fromJson(data['notification']),
        unreadCount: data['unreadCount'],
    ));
});
```

### 15.4 Badge Count Display Rules

| Unread Count | Display |
|---|---|
| 0 | No badge shown |
| 1–999 | Show exact number |
| 1,000–9,999 | Show as "1K", "5K", etc. |
| 10,000+ | Show "9K+" |
| Very large | Show "999+" if compact needed |

---

## 16. Security & Best Practices

### 16.1 FCM Token Security

- Never expose serviceAccountKey.json to the client — keep it server-side only ✅ (already in `/backend`)
- Validate JWT token before accepting FCM token registration requests
- Tokens per tenant should be isolated — never send cross-tenant pushes
- Clean up invalidated tokens when FCM returns `messaging/registration-token-not-registered`

### 16.2 Rate Limiting Notifications

- Implement **notification coalescing** for high-frequency events (e.g., campaign progress at every message would be too noisy — only notify at milestones: 25%, 50%, 75%, 100%)
- **Chat notification throttle**: If 10 messages arrive from the same contact within 60 seconds, send only 1 push notification per minute

### 16.3 User Notification Preferences

- Allow tenants to configure which notification types they want (per category toggle)
- Store preferences in tenant document:

```javascript
notificationPreferences: {
    chat: { push: true, inApp: true },
    campaigns: { push: true, inApp: true },
    payments: { push: true, inApp: true },
    leads: { push: true, inApp: true },
    chatbot: { push: false, inApp: true },  // example: push off
    system: { push: true, inApp: true },
}
```

### 16.4 Token Lifecycle Management

- On login: Register new FCM token
- On logout: Unsubscribe from FCM topics, mark token inactive
- On token refresh: Update token in database
- Periodic cleanup cron: Remove tokens not used in 90 days

---

## 17. Phased Implementation Roadmap

### Phase 1 — Foundation (Week 1–2) 🟢

- [ ] Install `firebase-admin` in backend
- [ ] Create `FCMService.js` (sendToDevice, sendToTenant, sendToTopic)
- [ ] Create `Notification` and `FCMToken` MongoDB schemas
- [ ] Create `NotificationService.js` (create, getForTenant, markRead, markAllRead)
- [ ] Add REST API endpoints (`/api/notifications/*`)
- [ ] Add FCM token registration endpoint

### Phase 2 — Flutter Integration (Week 2–3) 🟡

- [ ] Add `firebase_core`, `firebase_messaging`, `flutter_local_notifications` to pubspec.yaml
- [ ] Create `FCMService` (Dart) with background handler registration
- [ ] Create `NotificationBloc` with events/states
- [ ] Create `NotificationRepository` with API calls
- [ ] Build `NotificationBellIcon` widget with badge count
- [ ] Build `NotificationsPage` with list, mark-read, load more
- [ ] Integrate notification bell into AppBar across all pages
- [ ] Add socket listener for real-time `notification:new` events

### Phase 3 — Platform Setup (Week 3) 🟡

- [ ] Android: `google-services.json`, channel setup, AndroidManifest.xml
- [ ] iOS: `GoogleService-Info.plist`, APNs key upload to Firebase, Xcode capabilities
- [ ] Web: `firebase-messaging-sw.js` service worker, VAPID key, `index.html` setup

### Phase 4 — Trigger Integration (Week 3–4) 🟠

- [ ] Chat: Trigger on inbound WhatsApp message
- [ ] Campaigns: Trigger on complete/error/retry
- [ ] Leads: Trigger on new lead arrival
- [ ] Payments: Trigger on Razorpay success
- [ ] Scheduled campaigns: Trigger on execution
- [ ] Subscription: Cron-based expiry warnings (7 days before)
- [ ] Template: Trigger on Meta webhook approve/reject events

### Phase 5 — Polish & Advanced Features (Week 4–5) 🔴

- [ ] Notification preference settings UI
- [ ] Notification category filter tabs
- [ ] Deep-link navigation from notification tap
- [ ] Silent notification for real-time badge updates
- [ ] Rate limiting / coalescing logic
- [ ] Notification analytics (delivery rate, open rate)
- [ ] "Clear All" functionality
- [ ] Notification sound/vibration customization

---

## 18. Effort Estimate

| Phase | Component | Estimated Hours |
|---|---|---|
| Phase 1 | Backend Foundation | 16–20 hrs |
| Phase 2 | Flutter Integration | 20–25 hrs |
| Phase 3 | Platform Setup (Android/iOS/Web) | 10–15 hrs |
| Phase 4 | Trigger Integration (all modules) | 20–25 hrs |
| Phase 5 | Polish & Advanced | 15–20 hrs |
| **Total** | **Full Module** | **81–105 hrs** |

---

## Summary

| Decision | Chosen Solution |
|---|---|
| **Push Notification Service** | ✅ Firebase Cloud Messaging (FCM) |
| **Reason** | Already configured, free, universal platform support, official Flutter SDK |
| **In-App Notification Store** | ✅ MongoDB `notifications` collection |
| **Real-time Badge Updates** | ✅ Socket.io (foreground) + FCM silent push (background) |
| **Token Management** | ✅ MongoDB `fcm_tokens` + FCM Topics per tenant |
| **Read/Dismiss** | ✅ REST PATCH endpoint + Socket.io broadcast |
| **Background Push** | ✅ FCM native delivery (works when app is killed) |
| **Web Background Push** | ✅ Firebase Service Worker (PWA) |

> **Note:** The Firebase project `whatsapp-bulk-sender-9661e` already has a service account configured. The next immediate step is to install `firebase-admin` in the backend and `firebase_messaging` in Flutter, then register platform apps in the Firebase Console (Android, iOS, Web).

---

*Report generated: July 25, 2026 | Sendzyy Notification Module Research*
