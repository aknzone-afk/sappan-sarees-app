"use strict";

/**
 * SAPPAN SAREES retail app — cloud backend (codebase "sappan", 25-Oct-2026).
 *
 * Lives in the same Firebase project as the B.B Synthetics app but in its OWN
 * codebase with its OWN collections (sappan_*) and storage folder
 * (sappan_relay/). Deploying it never touches the B.B Synthetics functions:
 *     firebase deploy --only functions:sappan
 *
 * Orders go to the Telegram group whose title contains "Sappan" that the shop
 * bot (@Aknzonesales_bot) is in (or sappan_settings/telegram.chat when set).
 * Until such a group exists every order is HELD (photos in Storage, text in
 * Firestore) and spSweep posts it the moment the group appears — no order is
 * ever lost, and an order is posted only COMPLETE (photos + details together).
 */

const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// The shop bot's token (same bot as the B.B Synthetics app; read only).
const TG_TOKEN = defineSecret("BBAPP_TG_TOKEN");
const APP_KEY = "sappan-retail-app-2026"; // not a secret — keeps random traffic out
const REGION = "asia-south1";
const OPTS = { region: REGION, invoker: "public", maxInstances: 5, memory: "256MiB" };

const db = () => admin.firestore();
const appOk = (req) => req.get("x-app-key") === APP_KEY;
const digits = (m) => String(m || "").replace(/\D/g, "");
const key10 = (m) => { const d = digits(m); return d.length > 10 ? d.slice(-10) : d; };
const esc = (s) => String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const cut = (t, n) => { t = String(t || ""); return t.length <= n ? t : t.slice(0, n - 2) + " …"; };

const hits = new Map();
function limited(ip, max = 240) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < 3600e3);
  arr.push(now);
  hits.set(ip, arr);
  if (hits.size > 5000) hits.clear();
  return arr.length > max;
}

/** Wraps an app endpoint: POST + key + rate limit + JSON errors. */
function endpoint(fn, extra = {}) {
  return onRequest({ ...OPTS, ...extra }, async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ ok: false, error: "POST only" });
    if (!appOk(req)) return res.status(403).json({ ok: false, error: "bad key" });
    if (limited(req.ip || "?")) return res.status(429).json({ ok: false, error: "slow down" });
    try {
      const out = await fn(req.body || {}, req);
      return res.status(200).json(out);
    } catch (e) {
      logger.error("sappan endpoint", { error: e.message, stack: e.stack });
      return res.status(500).json({ ok: false, error: "server error" });
    }
  });
}

// ───────────────────────── Telegram ─────────────────────────

async function tg(method, body) {
  try {
    const r = await fetch(`https://api.telegram.org/bot${TG_TOKEN.value().trim()}/${method}`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (!j.ok) logger.warn("tg " + method, { code: j.error_code, desc: j.description });
    return j;
  } catch (e) {
    logger.warn("tg " + method, { error: e.message });
    return {};
  }
}

/** sendPhoto / sendMediaGroup with uploaded bytes. Waits out flood control. */
async function tgPhotos(chat, photos /* [{buf, caption}] */) {
  const ids = [];
  for (let i = 0; i < photos.length; i += 10) {
    const chunk = photos.slice(i, i + 10);
    for (let attempt = 0; attempt < 4; attempt++) {
      const fd = new FormData();
      fd.append("chat_id", String(chat));
      let method;
      if (chunk.length === 1) {
        method = "sendPhoto";
        fd.append("photo", new Blob([chunk[0].buf], { type: "image/jpeg" }), "p.jpg");
        if (chunk[0].caption) fd.append("caption", cut(chunk[0].caption, 1000));
      } else {
        method = "sendMediaGroup";
        fd.append("media", JSON.stringify(chunk.map((p, k) => ({
          type: "photo", media: `attach://p${k}`, ...(p.caption ? { caption: cut(p.caption, 1000) } : {}),
        }))));
        chunk.forEach((p, k) => fd.append(`p${k}`, new Blob([p.buf], { type: "image/jpeg" }), `p${k}.jpg`));
      }
      const r = await fetch(`https://api.telegram.org/bot${TG_TOKEN.value().trim()}/${method}`, { method: "POST", body: fd });
      const j = await r.json().catch(() => ({}));
      if (j.ok) {
        const res = Array.isArray(j.result) ? j.result : [j.result];
        res.forEach((m) => m && ids.push(m.message_id));
        break;
      }
      const wait = (j.parameters && j.parameters.retry_after) || 0;
      logger.warn("tg photos", { code: j.error_code, desc: j.description });
      if (j.error_code === 429 && wait && attempt < 3) { await new Promise((ok) => setTimeout(ok, (wait + 1) * 1000)); continue; }
      throw new Error("telegram photos: " + (j.description || r.status));
    }
  }
  return ids;
}

/** The Sappan orders group: setting first, else a bot group titled "…Sappan…". */
async function orderGroup() {
  const s = (await db().collection("sappan_settings").doc("telegram").get()).data();
  if (s && s.chat) return s.chat;
  // The shop bot remembers every group it is in (by title) — read only.
  const snap = await db().collection("bbapp_chats").get();
  let best = null;
  snap.forEach((d) => {
    const t = String((d.data() || {}).title || "");
    if (/sap+an|सपन|सप्पन|सापन/i.test(t) && (!best || (d.data().at || 0) > best.at)) best = { chat: d.id, title: t, at: d.data().at || 0 };
  });
  if (!best) return null;
  await db().collection("sappan_settings").doc("telegram").set({ chat: best.chat, title: best.title, at: Date.now(), auto: true });
  await tg("sendMessage", { chat_id: best.chat, text: "✅ Connected — every SAPPAN SAREES app order and sign-up will come here." });
  return best.chat;
}

// ───────────────────────── accounts ─────────────────────────

exports.spAccountSignup = endpoint(async (b) => {
  const m = key10(b.mobile);
  if (!/^[6-9]\d{9}$/.test(m)) return { ok: false, error: "mobile" };
  const c = b.cust || {};
  const cust = {
    name: cut(c.name || c.billName, 120), address: cut(c.address, 600), pincode: cut(c.pincode, 12),
    city: cut(c.city, 80), state: cut(c.state, 80),
  };
  const ref = db().collection("sappan_accounts").doc(m);
  const old = (await ref.get()).data();
  if (old && old.status === "blocked") return { ok: true, status: "blocked" };
  await ref.set({ mobile: m, cust, status: "approved", at: old ? old.at : Date.now(), updatedAt: Date.now(), signups: admin.firestore.FieldValue.increment(1) }, { merge: true });
  try {
    const chat = await orderGroup();
    if (chat) {
      await tg("sendMessage", {
        chat_id: chat, parse_mode: "HTML", disable_web_page_preview: true,
        text: `${old ? "🔁 Sign-up again" : "🆕 New sign-up"} — <b>SAPPAN SAREES app</b>\n👤 ${esc(cust.name)}\n📍 ${esc([cust.city, cust.state].filter(Boolean).join(", "))} ${esc(cust.pincode)}\n📱 +91 ${m} · <a href="https://wa.me/91${m}">WhatsApp</a>`,
      });
    }
  } catch (e) { logger.warn("signup note", { error: e.message }); }
  return { ok: true, status: "approved" };
}, { secrets: [TG_TOKEN] });

exports.spAccountStatus = endpoint(async (b) => {
  const m = key10(b.mobile);
  const a = (await db().collection("sappan_accounts").doc(m).get()).data();
  const patch = { seenAt: Date.now(), opens: admin.firestore.FieldValue.increment(1) };
  if (a) await db().collection("sappan_accounts").doc(m).set(patch, { merge: true });
  return { ok: true, status: a && a.status === "blocked" ? "blocked" : "approved" };
});

exports.spAccountDelete = endpoint(async (b) => {
  const m = key10(b.mobile);
  if (m) await db().collection("sappan_accounts").doc(m).delete();
  return { ok: true };
});

// ───────────────────────── orders ─────────────────────────

/** Reserves ORDER NO. for [ref] once (same number on every retry). */
async function reserve(b) {
  const ref = String(b.ref || "");
  if (!/^SAP-[\w-]{6,40}$/.test(ref)) throw new Error("bad ref");
  const oRef = db().collection("sappan_orders").doc(ref);
  const cRef = db().collection("sappan_counters").doc("orders");
  return db().runTransaction(async (t) => {
    const o = await t.get(oRef);
    if (o.exists && o.data().serial) {
      const patch = {};
      if (b.text && !o.data().pText) patch.pText = cut(b.text, 4000);
      if (b.items && !o.data().items) patch.items = b.items.slice(0, 200);
      if (Object.keys(patch).length) t.set(oRef, patch, { merge: true });
      return o.data().serial;
    }
    const c = await t.get(cRef);
    const no = ((c.exists && c.data().last) || 0) + 1;
    t.set(cRef, { last: no, at: Date.now() }, { merge: true });
    t.set(oRef, {
      ref, serial: no, mobile: key10(b.mobile), name: cut(b.billName, 120),
      cust: b.cust || null, note: cut(b.note, 2000),
      items: Array.isArray(b.items) ? b.items.slice(0, 200) : null,
      pText: b.text ? cut(b.text, 4000) : null,
      placedAt: Date.now(), status: "placed", buf: [],
    }, { merge: true });
    return no;
  });
}

exports.spPlaceOrder = endpoint(async (b) => ({ ok: true, no: await reserve(b) }));
exports.spNextOrderNo = endpoint(async (b) => ({ ok: true, no: await reserve(b) }));

const bucket = () => admin.storage().bucket();

exports.spOrderRelay = endpoint(async (b) => {
  const ref = String(b.ref || "");
  const oRef = db().collection("sappan_orders").doc(ref);
  const o = (await oRef.get()).data();
  if (!o) return { ok: false, error: "unknown order" };
  if (b.kind === "album") {
    // Held until the details arrive — the group only ever sees COMPLETE orders.
    const names = [];
    for (const p of (b.photos || []).slice(0, 10)) {
      const buf = Buffer.from(String(p), "base64");
      if (!buf.length || buf.length > 8e6) continue;
      const md5 = crypto.createHash("md5").update(buf).digest("hex");
      await bucket().file(`sappan_relay/${ref}/${md5}.jpg`).save(buf, { contentType: "image/jpeg", resumable: false });
      names.push(md5);
    }
    if (names.length) await oRef.update({ buf: admin.firestore.FieldValue.arrayUnion(...names) });
    return { ok: true, held: true, result: names.length === 1 ? {} : [] };
  }
  if (b.kind === "details") {
    await oRef.set({ dText: cut(b.text || o.pText, 4000), detailsAt: Date.now() }, { merge: true });
    const r = await deliver(ref);
    return { ok: true, result: r && r.msg ? { message_id: r.msg, chat: { id: r.chat } } : {} };
  }
  return { ok: true, result: {} }; // "no" / "dots": posted together with the details
}, { timeoutSeconds: 300, memory: "512MiB", secrets: [TG_TOKEN] });

exports.spRegisterOrder = endpoint(async () => ({ ok: true }));

exports.spOrderStatus = endpoint(async (b) => {
  const refs = (Array.isArray(b.refs) ? b.refs : []).slice(0, 60).map(String).filter((r) => /^SAP-/.test(r));
  const out = {};
  for (const r of refs) {
    const o = (await db().collection("sappan_orders").doc(r).get()).data();
    if (!o) continue;
    out[r] = { status: o.delivered ? (o.status === "placed" ? "received" : o.status) : null, steps: o.steps || {} };
  }
  return { ok: true, orders: out };
});

exports.spAppError = endpoint(async (b, req) => {
  await db().collection("sappan_errors").add({
    msg: cut(b.msg || b.error, 800), stack: cut(b.stack || b.st, 3000), ver: cut(b.ver || b.version, 40),
    os: cut(b.os, 40), at: Date.now(), ip: crypto.createHash("sha1").update(String(req.ip || "")).digest("hex").slice(0, 10),
  });
  return { ok: true };
});

// Not part of the retail app (wholesale-only features) — a calm "no".
for (const n of ["spPhoneLock", "spLookupParty", "spCheckNewParty", "spGstLookup", "spBillImage", "spPaymentProof",
  "spChatList", "spChatSend", "spChatFile", "spChatOpen", "spAccountVerify", "spAccountClaim", "spRegisterPush"]) {
  exports[n] = endpoint(async () => ({ ok: n === "spPhoneLock", allowed: true, mobiles: [], parties: [], messages: [] }));
}

/** Posts an order COMPLETE: photos (held, else Drive copies) → details → ORDER NO. → dots. */
async function deliver(ref) {
  const oRef = db().collection("sappan_orders").doc(ref);
  // one sender at a time
  const go = await db().runTransaction(async (t) => {
    const o = (await t.get(oRef)).data();
    if (!o || o.delivered) return null;
    if (o.sending && Date.now() - o.sending < 4 * 60e3) return null;
    t.update(oRef, { sending: Date.now() });
    return o;
  });
  if (!go) return null;
  const o = go;
  try {
    const chat = await orderGroup();
    if (!chat) { await oRef.update({ sending: 0, waitingGroup: true }); return null; }
    const items = Array.isArray(o.items) ? o.items : [];
    const capFor = (i) => {
      const it = items[i] || {};
      const parts = [`${i + 1}/${Math.max(items.length, (o.buf || []).length)}`];
      if (it.d) parts.push(`D.No ${it.d}`);
      if (it.p) parts.push(`₹${it.p}`);
      const pick = it.k || it.pick;
      parts.push(pick ? `${pick} (${it.q || it.qty || 1} pcs)` : `${it.q || it.qty || 1} pcs`);
      const f = String(it.f || "").split("/").filter(Boolean).join(" › ");
      return parts.join(" · ") + (f ? "\n" + f : "");
    };
    const photos = [];
    const held = o.buf || [];
    for (let i = 0; i < held.length; i++) {
      try {
        const [buf] = await bucket().file(`sappan_relay/${ref}/${held[i]}.jpg`).download();
        photos.push({ buf, caption: capFor(i) });
      } catch (e) { logger.warn("held photo", { ref, error: e.message }); }
    }
    // Phone stopped before sending its photos: the shop still gets every design.
    for (let i = photos.length; i < items.length; i++) {
      const id = items[i] && (items[i].id || items[i].i);
      if (!id) continue;
      try {
        const r = await fetch(`https://drive.google.com/thumbnail?id=${encodeURIComponent(id)}&sz=w1600`);
        if (r.ok) photos.push({ buf: Buffer.from(await r.arrayBuffer()), caption: capFor(i) + "\n☁️ photo from the catalogue" });
      } catch (e) { /* the details still name the design */ }
    }
    const extra = await tgPhotos(chat, photos);
    const text = o.dText || o.pText || `🛍️ <b>SAPPAN SAREES — RETAIL ORDER</b>\n📱 +91 ${o.mobile}`;
    const d = await tg("sendMessage", { chat_id: chat, text: cut(text, 4000), parse_mode: "HTML", disable_web_page_preview: true });
    if (!d.ok) throw new Error("details: " + (d.description || "?"));
    const n = await tg("sendMessage", { chat_id: chat, text: `ORDER NO. ${o.serial}` });
    await tg("sendMessage", { chat_id: chat, text: ".\n." });
    await oRef.update({
      delivered: true, deliveredAt: Date.now(), status: "received", sending: 0, waitingGroup: false,
      chat: String(chat), msg: d.result.message_id, extra: [...extra, n.result ? n.result.message_id : 0].filter(Boolean),
    });
    try { await bucket().deleteFiles({ prefix: `sappan_relay/${ref}/` }); } catch (e) { /* kept; harmless */ }
    return { chat, msg: d.result.message_id };
  } catch (e) {
    logger.error("deliver", { ref, error: e.message });
    await oRef.update({ sending: 0, lastError: cut(e.message, 300) });
    return null;
  }
}

/** Every 5 min: orders the phone never finished (10+ min old) or held for the group. */
exports.spSweep = onSchedule({ region: REGION, schedule: "every 5 minutes", secrets: [TG_TOKEN], timeoutSeconds: 540, memory: "512MiB" }, async () => {
  const snap = await db().collection("sappan_orders").where("status", "==", "placed").limit(50).get();
  for (const d of snap.docs) {
    const o = d.data();
    const since = Date.now() - (o.detailsAt || o.placedAt || 0);
    if (o.delivered || (!o.detailsAt && since < 10 * 60e3)) continue;
    await deliver(d.id);
  }
});

/** Health check: which Telegram group orders go to (title only). */
exports.spHealth = endpoint(async () => {
  const chat = await orderGroup();
  const s = (await db().collection("sappan_settings").doc("telegram").get()).data();
  return { ok: true, group: chat ? (s && s.title) || "set" : null };
}, { secrets: [TG_TOKEN] });

// ───────────────────────── share links (owner 26-Oct-2026) ─────────────────────────

const IOS_STORE = "https://apps.apple.com/app/id6826903241";
const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.sappansarees.retailapp";
const SHARE_FN = "https://asia-south1-akn-chat-a7dd8.cloudfunctions.net";
let _prices = { at: 0, p: {} };
async function wholesaleOf(id) {
  if (Date.now() - _prices.at > 10 * 60e3) {
    try {
      const r = await fetch("https://aknzone-afk.github.io/akn-zone-data/app/prices.json?t=" + Date.now());
      const j = await r.json();
      _prices = { at: Date.now(), p: (j && j.p) || {} };
    } catch (e) { /* keep old */ }
  }
  const v = Number(_prices.p[id]);
  return Number.isFinite(v) && v > 0 ? v : null;
}
const okId = (id) => /^[A-Za-z0-9_-]{10,80}$/.test(String(id || ""));
const rupees = (n) => "₹" + Number(n).toLocaleString("en-IN");

/** The saree photo with the shop's bottom label strip cropped off (link previews). */
exports.spShareImg = onRequest({ ...OPTS, memory: "512MiB" }, async (req, res) => {
  const id = String(req.query.d || "");
  if (!okId(id)) return res.status(400).send("bad id");
  try {
    const r = await fetch(`https://drive.google.com/thumbnail?id=${encodeURIComponent(id)}&sz=w1200`);
    if (!r.ok) return res.status(404).send("not found");
    const buf = Buffer.from(await r.arrayBuffer());
    const sharp = require("sharp");
    const img = sharp(buf);
    const m = await img.metadata();
    const h = Math.round(m.height * 0.80); // the price / fabric boxes sit in the bottom ~20%
    const out = await img.extract({ left: 0, top: 0, width: m.width, height: h }).jpeg({ quality: 84 }).toBuffer();
    res.set("Cache-Control", "public, max-age=86400");
    res.type("image/jpeg").send(out);
  } catch (e) {
    logger.warn("spShareImg", { error: e.message });
    res.status(500).send("error");
  }
});

/** Share page: shows the saree, opens the app on it, else the right store. */
exports.spShare = onRequest({ ...OPTS }, async (req, res) => {
  const id = String(req.query.d || "");
  if (!okId(id)) return res.redirect(302, IOS_STORE);
  const w = await wholesaleOf(id);
  const price = w && w >= 400 ? rupees(w * 2) : null;
  const img = `${SHARE_FN}/spShareImg?d=${encodeURIComponent(id)}`;
  const deep = `sappansarees://open/p/${encodeURIComponent(id)}`;
  const intent = `intent://open/p/${encodeURIComponent(id)}#Intent;scheme=sappansarees;package=com.sappansarees.retailapp;S.browser_fallback_url=${encodeURIComponent(PLAY_STORE)};end`;
  const title = "Sappan Sarees" + (price ? " · " + price : "");
  res.set("Cache-Control", "public, max-age=600");
  res.type("html").send(`<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="The finest weaves of India — tap to view this saree in the Sappan Sarees app.">
<meta property="og:image" content="${img}">
<meta property="og:type" content="product">
<meta name="twitter:card" content="summary_large_image">
<style>
 body{margin:0;background:#22030b;color:#fffcf7;font-family:Georgia,serif;text-align:center}
 .wrap{max-width:520px;margin:0 auto;padding:22px 16px 40px}
 h1{letter-spacing:.45em;font-size:26px;margin:8px 0 2px;color:#fffcf7}
 .sub{color:#c6a15b;letter-spacing:.3em;font:600 10px/1 system-ui,sans-serif;margin-bottom:18px}
 img{width:100%;border:1px solid #c6a15b55;display:block}
 .price{font-size:26px;color:#e9d9b4;margin:16px 0 4px}
 a.btn{display:block;margin:14px 0 0;padding:15px;border:1px solid #c6a15b;color:#22030b;background:#e9d9b4;text-decoration:none;font:700 13px system-ui,sans-serif;letter-spacing:.18em}
 a.alt{background:transparent;color:#e9d9b4}
 .note{font:12px system-ui,sans-serif;color:#e9d9b4aa;margin-top:18px;line-height:1.5}
</style></head><body><div class="wrap">
<h1>SAPPAN</h1><div class="sub">THE FINEST WEAVES OF INDIA</div>
<img src="${img}" alt="Saree">
${price ? `<div class="price">${esc(price)}</div>` : ""}
<a class="btn" id="open" href="${deep}">OPEN IN THE APP</a>
<a class="btn alt" id="get" href="${IOS_STORE}">GET THE APP</a>
<div class="note">New here? Install Sappan Sarees, sign up in 30 seconds, then tap this link again to open this saree.</div>
</div><script>
 var ua=navigator.userAgent||"", android=/Android/i.test(ua), ios=/iPhone|iPad|iPod/i.test(ua);
 var get=document.getElementById("get"), open=document.getElementById("open");
 get.href = android ? ${JSON.stringify(PLAY_STORE)} : ${JSON.stringify(IOS_STORE)};
 if (android) open.href = ${JSON.stringify(intent)};
 function go(){ if(android){ location.href=${JSON.stringify(intent)}; }
   else if(ios){ var t=Date.now(); location.href=${JSON.stringify(deep)};
     setTimeout(function(){ if(!document.hidden && Date.now()-t<2500) location.href=${JSON.stringify(IOS_STORE)}; },1600); } }
 if(android||ios) setTimeout(go,350);
</script></body></html>`);
});
