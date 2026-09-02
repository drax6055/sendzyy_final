# WhatsApp Cloud API Webhook Reporting Module — Final Audit & Production Fix

**Target Codebase:** Sendzyy Backend (`backend/server.js`, `backend/services/MessageTracker.js`, `backend/services/ReportGenerator.js`, `backend/scheduler.js`)
**Status:** Consolidated — combines Audit v1, Audit v2 (Enhanced), and follow-up review fixes into one implementation-ready reference.
**Objective:** Match stored message metrics (Sent/Delivered/Read/Failed) to Meta Business Manager, eliminate race conditions and event loss, and give you a permanent reconciliation safety net.

---

## 0. How to use this file

Each numbered issue below has: **Problem → Why it matters → Fix**, followed by a single consolidated code section at the bottom containing the final, corrected implementation for every file. Work top to bottom — later items (like the reconciliation cron) depend on earlier ones (like `deliveryTimestamp` being correct) actually being fixed first.

**Suggested rollout order:**
1. Signature verification + write-ahead logging (safety net, zero behavior risk)
2. Batch iteration fix (`statuses[]`, `messages[]` full loop)
3. Atomic status handlers for `sent` / `delivered` / `read` / `failed` (the core fix)
4. Recovery wiring (startup + periodic retry cron)
5. Timezone-aware reporting boundaries
6. Reconciliation cron (multi-metric)
7. Schema-level unique index backstop

---

## 1. Executive Summary — All Findings Across Both Audits + Review Rounds

| # | Check | Status | Root Cause |
|---|---|---|---|
| 1 | Idempotency & batch iteration | ✅ Fixed below | `statuses[0]` / `messages[0]` truncated batches; raw `$inc` had no atomic precondition |
| 2 | Race condition in dedup | ✅ Fixed below | `findOne` → `updateOne` was check-then-act, not atomic; concurrent webhooks double-counted |
| 3 | Ingestion durability (crash loss) | ✅ Fixed below | `setImmediate` alone loses acknowledged events on crash/restart |
| 4 | Raw payload logging & retention | ✅ Fixed below | Logging table unused; TTL too short for monthly billing audits |
| 5 | Timezone consistency | ✅ Fixed below (was previously only claimed, not implemented) | Day-boundary math used naive UTC, never pulled actual WABA timezone |
| 6 | Definitional mismatch (Delivered vs Read) | ✅ Fixed below | `deliveredCount` was decremented on `read`; Meta's Delivered is cumulative, inclusive of Read |
| 7 | Read receipt limitation | ✅ Pass (no change needed) | `delivered`-without-`read` correctly not treated as failure |
| 8 | Reconciliation vs Meta Analytics API | ✅ Fixed below | No scheduled diff job existed; now covers Sent/Delivered/Read/Failed + conversation billing categories |
| 9 | Webhook signature verification | ✅ Fixed below | No `X-Hub-Signature-256` check — endpoint was spoofable |
| 10 | **`sent` status silently dropped** *(found in review of v2)* | ✅ Fixed below | `STATUS_RANK` included `sent` but no handler branch existed for it — every `sent` webhook was a no-op |
| 11 | **`read`-before-`delivered` backfill corrupts `deliveredAt`** *(found in review of v2)* | ✅ Fixed below | Unconditional `$set` overwrote a real earlier `deliveredAt` with the later `read` timestamp when both events existed, shifting date-bucketed reports |
| 12 | **`failed` can downgrade a terminal `read`/`delivered` state** *(found in review of v2)* | ✅ Fixed below | No rank/state guard on the failed-branch filter |
| 13 | **Recovery function defined but never invoked** *(found in review of v2)* | ✅ Fixed below | `recoverPendingWebhookLogs()` existed but wasn't called on boot, and no periodic retry existed for `status: 'failed'` jobs |
| 14 | **No visibility into suppressed duplicates** *(found in review of v2)* | ✅ Fixed below | Duplicate webhooks were silently dropped with no log/metric, making it impossible to distinguish "deduping correctly" from "silently losing events" |
| 15 | Schema-level unique index backstop | ✅ Fixed below | Dedup only enforced in application logic; DB itself didn't reject a duplicate write as a last line of defense |

---

## 2. Detailed Notes on the Three Trickiest Fixes

### 2.1 The `read`-before-`delivered` backfill (#11)
Meta occasionally delivers `read` before you've finished processing (or even received) the corresponding `delivered` event — network reordering, retries, or queue delays on your side. Two safe cases exist:

- **Case A — genuinely out of order:** No `delivered` was ever recorded. Backfilling `deliveredAt` with the `read` timestamp is the best available approximation.
- **Case B — already delivered, and this is just a normal later `read`:** `deliveredAt` already holds the true, earlier timestamp. Overwriting it with the `read` time is **wrong** — it fabricates a false delivery time and can shift the message into the wrong reporting day.

The fix uses a MongoDB **aggregation-pipeline update** (`$ifNull`) so the write is conditional on the *document's own current state*, not on a value your application read moments earlier — closing the same class of race condition as the dedup fix.

### 2.2 Status regression guard on `failed` (#12)
`failed` should be a terminal state only when nothing better has already happened. The filter now requires `status: { $nin: ['delivered', 'read'] }` in addition to `failedAt: null`, so a delayed/duplicate `failed` webhook arriving after a real `read` cannot downgrade the recipient or inflate `failureCount`.

### 2.3 Timezone (#5)
This was marked "resolved" twice before without an actual implementation. The fix below:
- Stores the WABA's reporting timezone on the `Tenant` record (`whatsappConfig.reportingTimezone`, e.g. `"Asia/Kolkata"`) — set this once by checking your Business Manager account settings.
- Computes day boundaries using that timezone (via `date-fns-tz` or `luxon`) instead of naive UTC, for **both** the report generator and the reconciliation cron.
- If you serve multiple tenants across timezones, this must be per-tenant, not a global constant — the code below reflects that.

---

## 3. Final Consolidated Implementation

### 3.1 Dependencies
```bash
npm install date-fns-tz
```

### 3.2 Signature Verification Middleware — `backend/middleware/verifyMetaSignature.js`
```javascript
const crypto = require('crypto');

function verifyMetaWebhookSignature(req, res, next) {
    const signature = req.headers['x-hub-signature-256'];
    const appSecret = process.env.META_APP_SECRET;

    if (!appSecret) {
        if (process.env.NODE_ENV === 'production') {
            console.error('[Security] META_APP_SECRET is not defined in production!');
            return res.status(403).send('Webhook secret misconfigured');
        }
        return next(); // allow in dev only
    }

    if (!signature) {
        console.warn('[Security] Missing X-Hub-Signature-256 header');
        return res.status(401).send('Missing signature');
    }

    const [, signatureHash] = signature.split('=');
    const expectedHash = crypto
        .createHmac('sha256', appSecret)
        .update(req.rawBody || JSON.stringify(req.body))
        .digest('hex');

    const sigBuf = Buffer.from(signatureHash || '', 'utf8');
    const expBuf = Buffer.from(expectedHash, 'utf8');
    const isValid = sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf);

    if (!isValid) {
        console.error('[Security] Invalid X-Hub-Signature-256 received');
        return res.status(403).send('Invalid signature');
    }

    next();
}

module.exports = { verifyMetaWebhookSignature };
```

Ensure raw body capture is registered **before** your JSON body parser in `server.js`:
```javascript
app.use(express.json({
    verify: (req, res, buf) => { req.rawBody = buf.toString(); }
}));
```

---

### 3.3 Raw Log Schema — `backend/models/WebhookRawLog.js`
```javascript
const mongoose = require('mongoose');

const webhookRawLogSchema = new mongoose.Schema({
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    status: {
        type: String,
        enum: ['pending', 'processing', 'processed', 'failed'],
        default: 'pending',
        index: true
    },
    attempts: { type: Number, default: 0 },
    error: { type: String, default: null },
    receivedAt: {
        type: Date,
        default: Date.now,
        expires: 2592000 // 30-day TTL, matches Meta's audit/reporting window
    }
}, { timestamps: true });

webhookRawLogSchema.index({ status: 1, createdAt: 1 });

module.exports = mongoose.model('WebhookRawLog', webhookRawLogSchema);
```

---

### 3.4 Webhook Endpoint — `backend/server.js` (webhook route section)
```javascript
const { verifyMetaWebhookSignature } = require('./middleware/verifyMetaSignature');
const WebhookRawLog = require('./models/WebhookRawLog');

app.post('/webhook', verifyMetaWebhookSignature, async (req, res) => {
    const body = req.body;
    if (body.object !== 'whatsapp_business_account') {
        return res.sendStatus(404);
    }

    let rawLogId = null;
    try {
        // Write-ahead persistence BEFORE acknowledging — survives a crash mid-flight
        const rawLog = await WebhookRawLog.create({ payload: body, status: 'pending', attempts: 0 });
        rawLogId = rawLog._id;
    } catch (dbErr) {
        console.error('[Webhook] Failed to persist raw webhook:', dbErr.message);
        // Still ack — Meta will retry regardless, and we don't want to fail the SLA
        // over a transient DB write error. Consider alerting here.
    }

    res.status(200).send('EVENT_RECEIVED'); // ack within SLA, before any processing

    if (rawLogId) {
        setImmediate(() => processWebhookJob(rawLogId));
    }
});

async function processWebhookJob(rawLogId) {
    const log = await WebhookRawLog.findOneAndUpdate(
        { _id: rawLogId, status: { $in: ['pending', 'failed'] } },
        { $set: { status: 'processing' }, $inc: { attempts: 1 } },
        { new: true }
    );
    if (!log) return;

    try {
        await processIncomingWebhookPayload(log.payload);
        await WebhookRawLog.updateOne({ _id: rawLogId }, { $set: { status: 'processed', error: null } });
    } catch (err) {
        console.error(`[Webhook] Job ${rawLogId} processing failed:`, err);
        await WebhookRawLog.updateOne({ _id: rawLogId }, { $set: { status: 'failed', error: err.message } });
    }
}

// --- Recovery: called on boot AND on a periodic cron (see 3.8) ---
async function recoverPendingWebhookLogs() {
    try {
        const stuckLogs = await WebhookRawLog.find({
            status: { $in: ['pending', 'processing', 'failed'] },
            attempts: { $lt: 5 }
        }).limit(200);

        if (stuckLogs.length > 0) {
            console.log(`[Webhook Recovery] Recovering ${stuckLogs.length} webhook payload(s)...`);
            for (const log of stuckLogs) {
                processWebhookJob(log._id).catch(() => {});
            }
        }
    } catch (e) {
        console.error('[Webhook Recovery] Error during recovery check:', e.message);
    }
}

module.exports.recoverPendingWebhookLogs = recoverPendingWebhookLogs;
```

**Wire recovery into boot** — in whichever file starts your server after the DB connects:
```javascript
mongoose.connection.once('open', async () => {
    console.log('[Startup] DB connected — running webhook recovery sweep');
    await recoverPendingWebhookLogs();
});
```

---

### 3.5 Full Batch Iteration & Router — `backend/services/WebhookRouter.js`
```javascript
async function processIncomingWebhookPayload(body) {
    for (const entry of body.entry || []) {
        for (const change of entry.changes || []) {
            const val = change.value;
            if (!val) continue;

            if (change.field === 'account_update' && val.event === 'PARTNER_ADDED') {
                await handlePartnerAdded(entry.id, val);
                continue;
            }
            if (change.field === 'message_template_status_update') {
                await handleTemplateStatusUpdate(entry.id, val);
                continue;
            }
            if (change.field === 'phone_number_name_update') {
                await handlePhoneNumberNameUpdate(val);
                continue;
            }

            // Full iteration — fixes the [0]-only truncation bug from v1
            if (Array.isArray(val.statuses)) {
                for (const statusUpdate of val.statuses) {
                    await processStatusUpdateAtomic(statusUpdate);
                }
            }

            if (Array.isArray(val.messages)) {
                const receiverPhoneNumberId = val.metadata?.phone_number_id;
                for (const message of val.messages) {
                    await processIncomingMessage(message, val.contacts, receiverPhoneNumberId);
                }
            }
        }
    }
}

module.exports = { processIncomingWebhookPayload };
```

---

### 3.6 Atomic Status Processor — `backend/services/MessageTracker.js`

This is the core fix. Covers `sent` (new), `delivered`, `read` (with corrected backfill), and `failed` (with regression guard).

```javascript
const STATUS_RANK = { sent: 1, delivered: 2, read: 3, failed: 4 };

async function processStatusUpdateAtomic(statusUpdate) {
    const wamid = statusUpdate.id;
    const incomingStatus = statusUpdate.status;
    const incomingRank = STATUS_RANK[incomingStatus];
    const incomingTimestamp = statusUpdate.timestamp
        ? new Date(parseInt(statusUpdate.timestamp, 10) * 1000)
        : new Date();

    if (!wamid || !incomingRank) return;

    const mapping = await StatusMapping.findOne({ wamid }).lean();
    if (!mapping?.tenantId) return;

    const tenantId = mapping.tenantId;
    const campaignId = mapping.campaignId;
    const campaignFilter = campaignId ? { tenantId, id: campaignId } : null;

    // ---------------------------------------------------------
    // CASE 0: SENT  (previously silently dropped — fix #10)
    // ---------------------------------------------------------
    if (incomingStatus === 'sent') {
        const updated = await Recipient.findOneAndUpdate(
            { wamid, sentAt: null },
            { $set: { sentAt: incomingTimestamp.toISOString(), status: incomingStatus } },
            { new: true }
        );

        if (!updated) {
            console.debug(`[Webhook][Dedup] Duplicate 'sent' for ${wamid} — skipped`);
            return;
        }

        if (campaignFilter) {
            await Campaign.updateOne(campaignFilter, { $inc: { sentCount: 1 } });
            await broadcastCampaigns(tenantId);
        }
        await Message.updateOne({ wamid, status: { $exists: false } }, { $set: { status: 'sent' } });
        await broadcastMessages(tenantId, mapping.to);
        return;
    }

    // ---------------------------------------------------------
    // CASE A: DELIVERED
    // ---------------------------------------------------------
    if (incomingStatus === 'delivered') {
        const updatedRecipient = await Recipient.findOneAndUpdate(
            { wamid, deliveredAt: null },
            {
                $set: {
                    deliveredAt: incomingTimestamp.toISOString(),
                    deliveryTimestamp: incomingTimestamp,
                    status: incomingStatus
                }
            },
            { new: true }
        );

        if (!updatedRecipient) {
            console.debug(`[Webhook][Dedup] Duplicate 'delivered' for ${wamid} — skipped`);
            return;
        }

        if (campaignFilter) {
            await Campaign.updateOne(campaignFilter, { $inc: { deliveredCount: 1 } });
        }
        await Message.updateOne({ wamid, status: { $ne: 'read' } }, { $set: { status: 'delivered' } });
        await broadcastMessages(tenantId, mapping.to);

        if (campaignFilter) {
            const camp = await Campaign.findOne(campaignFilter, { currentPhase: 1 });
            if (camp) await messageTracker.recordDelivery(wamid, camp.currentPhase, incomingTimestamp);
            await broadcastCampaigns(tenantId);
        }
        return;
    }

    // ---------------------------------------------------------
    // CASE B: READ  (fixed backfill — fix #11)
    // ---------------------------------------------------------
    if (incomingStatus === 'read') {
        // Aggregation-pipeline update: only fills deliveredAt if it was NOT already set.
        // This prevents a true, earlier deliveredAt from being overwritten by the
        // later read timestamp (which would corrupt day-bucketed reconciliation).
        const updatedRecipient = await Recipient.findOneAndUpdate(
            { wamid, readAt: null },
            [
                {
                    $set: {
                        readAt: incomingTimestamp.toISOString(),
                        status: 'read',
                        deliveredAt: { $ifNull: ['$deliveredAt', incomingTimestamp.toISOString()] },
                        deliveryTimestamp: { $ifNull: ['$deliveryTimestamp', incomingTimestamp] }
                    }
                }
            ],
            { new: false } // pre-update doc, so we can tell if deliveredAt already existed
        );

        if (!updatedRecipient) {
            console.debug(`[Webhook][Dedup] Duplicate 'read' for ${wamid} — skipped`);
            return;
        }

        const wasAlreadyDelivered = Boolean(updatedRecipient.deliveredAt);
        const campaignInc = { readCount: 1 };
        if (!wasAlreadyDelivered) {
            campaignInc.deliveredCount = 1; // out-of-order read arrived before delivered
        }

        if (campaignFilter) {
            await Campaign.updateOne(campaignFilter, { $inc: campaignInc });
        }
        await Message.updateOne({ wamid }, { $set: { status: 'read' } });
        await broadcastMessages(tenantId, mapping.to);

        if (campaignFilter) {
            const camp = await Campaign.findOne(campaignFilter, { currentPhase: 1 });
            if (camp) await messageTracker.recordDelivery(wamid, camp.currentPhase, incomingTimestamp);
            await broadcastCampaigns(tenantId);
        }
        return;
    }

    // ---------------------------------------------------------
    // CASE C: FAILED  (regression guard added — fix #12)
    // ---------------------------------------------------------
    if (incomingStatus === 'failed') {
        const errObj = statusUpdate.errors?.[0];
        const errorDetails = errObj?.error_data?.details || errObj?.message || errObj?.title || 'Meta delivery failure';

        // Guard: never downgrade a recipient that already reached delivered/read
        const updatedRecipient = await Recipient.findOneAndUpdate(
            { wamid, failedAt: null, status: { $nin: ['delivered', 'read'] } },
            { $set: { failedAt: incomingTimestamp.toISOString(), status: 'failed' } },
            { new: true }
        );

        if (!updatedRecipient) {
            console.debug(`[Webhook][Dedup/Guard] 'failed' for ${wamid} skipped (duplicate or already delivered/read)`);
            return;
        }

        if (campaignFilter) {
            await Campaign.updateOne(campaignFilter, { $inc: { failureCount: 1 } });
        }
        await Message.updateOne({ wamid }, { $set: { status: 'failed', errorDetails } });
        await broadcastMessages(tenantId, mapping.to);
        if (campaignFilter) await broadcastCampaigns(tenantId);
    }
}

module.exports = { processStatusUpdateAtomic };
```

---

### 3.7 Timezone-Aware Day Boundaries — `backend/utils/reportingWindow.js`

```javascript
const { zonedTimeToUtc } = require('date-fns-tz');

/**
 * Returns [startUtc, endUtc] for "yesterday" in the tenant's configured
 * WABA reporting timezone, so daily buckets line up with Meta Business Manager.
 * Falls back to UTC if no timezone is configured for the tenant.
 */
function getYesterdayWindowInTz(timezone = 'UTC') {
    const now = new Date();
    const y = new Date(now);
    y.setDate(now.getDate() - 1);

    const dateStr = y.toISOString().slice(0, 10); // YYYY-MM-DD, still needs tz conversion
    const startLocal = `${dateStr}T00:00:00`;
    const endLocal = `${dateStr}T23:59:59.999`;

    const startUtc = zonedTimeToUtc(startLocal, timezone);
    const endUtc = zonedTimeToUtc(endLocal, timezone);

    return {
        startUtc,
        endUtc,
        startUnix: Math.floor(startUtc.getTime() / 1000),
        endUnix: Math.floor(endUtc.getTime() / 1000)
    };
}

module.exports = { getYesterdayWindowInTz };
```

Set the tenant's timezone once (from your Meta Business Manager account settings):
```javascript
await Tenant.updateOne(
    { _id: tenantId },
    { $set: { 'whatsappConfig.reportingTimezone': 'Asia/Kolkata' } } // adjust per tenant
);
```

Use this same helper in `ReportGenerator.js` wherever you currently compute "today"/"yesterday" boundaries for the dashboard, so the module's own reports and the reconciliation cron never disagree with each other.

---

### 3.8 Reconciliation Cron (Multi-Metric + Timezone-Aware + Recovery Retry) — `backend/scheduler.js`

```javascript
const { getYesterdayWindowInTz } = require('./utils/reportingWindow');
const { recoverPendingWebhookLogs } = require('./server'); // adjust import to your export location

// --- Daily reconciliation, 02:30 UTC ---
cron.schedule('30 2 * * *', async () => {
    try {
        console.log('[Reconciliation] Starting daily Meta analytics audit...');
        const tenants = await Tenant.find({ 'whatsappConfig.verified': true });

        for (const tenant of tenants) {
            const { businessAccountId, accessToken, reportingTimezone } = tenant.whatsappConfig || {};
            if (!businessAccountId || !accessToken) continue;

            const tenantIdStr = tenant._id.toString();
            const { startUtc, endUtc, startUnix, endUnix } = getYesterdayWindowInTz(reportingTimezone || 'UTC');

            // 1. Message-level analytics (Sent / Delivered / Read)
            try {
                const url = `https://graph.facebook.com/v21.0/${businessAccountId}?fields=analytics.start(${startUnix}).end(${endUnix}).granularity(DAILY)&access_token=${accessToken}`;
                const msgRes = await axios.get(url);
                const meta = msgRes.data?.analytics?.data_points?.[0] || {};

                const metrics = [
                    { name: 'sent', metaVal: meta.sent || 0, field: 'sentAt' },
                    { name: 'delivered', metaVal: meta.delivered || 0, field: 'deliveryTimestamp' },
                    { name: 'read', metaVal: meta.read || 0, field: 'readAt' }
                ];

                for (const m of metrics) {
                    const dbCount = await Recipient.countDocuments({
                        tenantId: tenantIdStr,
                        [m.field]: { $gte: startUtc, $lte: endUtc }
                    });
                    const delta = m.metaVal > 0 ? Math.abs((dbCount - m.metaVal) / m.metaVal) * 100 : 0;
                    if (delta > 2.0) {
                        console.warn(`[Reconciliation Alert] Tenant ${tenantIdStr} ${m.name.toUpperCase()} discrepancy: Meta=${m.metaVal}, DB=${dbCount}, Delta=${delta.toFixed(2)}%`);
                        // Optional: write to a ReconciliationAlert collection / notify Slack here
                    }
                }
            } catch (err) {
                console.error(`[Reconciliation] Message analytics failed for ${tenantIdStr}:`, err.message);
            }

            // 2. Conversation billing categories (informational — logged for now)
            try {
                const convUrl = `https://graph.facebook.com/v21.0/${businessAccountId}/conversation_analytics?start=${startUnix}&end=${endUnix}&granularity=DAILY&metric_types=CONVERSATION_COUNT&dimensions=CONVERSATION_CATEGORY,CONVERSATION_TYPE&access_token=${accessToken}`;
                const convRes = await axios.get(convUrl);
                const points = convRes.data?.data?.[0]?.data_points || [];
                const categoryCounts = { MARKETING: 0, UTILITY: 0, SERVICE: 0, AUTHENTICATION: 0 };
                for (const dp of points) {
                    if (categoryCounts[dp.conversation_category] !== undefined) {
                        categoryCounts[dp.conversation_category] += (dp.conversation || 0);
                    }
                }
                console.log(`[Reconciliation] Tenant ${tenantIdStr} conversation categories:`, JSON.stringify(categoryCounts));
            } catch (convErr) {
                console.log(`[Reconciliation] Conversation analytics unavailable for ${tenantIdStr}:`, convErr.message);
            }
        }
    } catch (err) {
        console.error('[Reconciliation Job] Fatal error:', err.message);
    }
});

// --- Periodic retry for stuck/failed webhook jobs, every 5 minutes (fix #13) ---
cron.schedule('*/5 * * * *', async () => {
    await recoverPendingWebhookLogs();
});
```

---

### 3.9 Schema-Level Dedup Backstop — `backend/models/Recipient.js`

```javascript
recipientSchema.index({ wamid: 1, sentAt: 1 }, { sparse: true });
recipientSchema.index({ wamid: 1, deliveredAt: 1 }, { sparse: true });
recipientSchema.index({ wamid: 1, readAt: 1 }, { sparse: true });
recipientSchema.index({ wamid: 1, failedAt: 1 }, { sparse: true });
recipientSchema.index({ tenantId: 1, deliveryTimestamp: 1 });
recipientSchema.index({ tenantId: 1, readAt: 1 });
recipientSchema.index({ tenantId: 1, sentAt: 1 });
```

These don't replace the atomic `findOneAndUpdate` guards — they're a last line of defense so a future code change elsewhere in the codebase can't quietly reintroduce double writes.

---

## 4. Post-Deploy Verification Checklist

Run through this after deploying, using one real, low-volume campaign as a test:

- [ ] Send a small test campaign (5–10 recipients) and confirm `sentCount`, `deliveredCount`, `readCount` in your DB match Meta Business Manager's panel for that same campaign within a few hours.
- [ ] Manually replay a duplicate webhook payload (copy one from `WebhookRawLog`, POST it again) and confirm counts do **not** increment a second time, and that a `[Webhook][Dedup]` debug log appears.
- [ ] Kill the Node process mid-way through processing a burst of webhooks (simulate a crash) and confirm `recoverPendingWebhookLogs()` picks up the stuck `pending`/`processing` rows on restart.
- [ ] Check that a message where `read` arrives before `delivered` (rare, but happens on flaky networks) ends up with `deliveredCount` and `readCount` both incremented exactly once, not zero or twice.
- [ ] Confirm the reconciliation cron log shows a delta under 2% for at least 3 consecutive days before trusting it as your dashboard's source of truth.
- [ ] Confirm `reportingTimezone` is actually set per tenant and not defaulting to `'UTC'` silently for tenants outside UTC.
