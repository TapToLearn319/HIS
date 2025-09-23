// functions/index.js
"use strict";

const {onRequest} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2/options");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

setGlobalOptions({region: "asia-northeast3"});

/**
 * Normalize slotIndex to "1" or "2" or null.
 * @param {*} v
 * @return {string|null}
 */
function normalizeSlot(v) {
  if (v === null || v === undefined) return null;
  const s = String(v);
  return s === "1" || s === "2" ? s : null;
}

/**
 * Resolve sessionId in priority:
 * 1) client-sent sessionId
 * 2) hubs/{hubId}.currentSessionId
 * 3) devices/{deviceId}.hubId -> hubs/{hubId}.currentSessionId
 * @param {{hubId:string?, deviceId:string?, clientSessionId:string?}} p
 * @return {Promise<string>}
 */
async function resolveSessionId(p) {
  const hubId = p.hubId;
  const deviceId = p.deviceId;
  const clientSessionId = p.clientSessionId;

  if (clientSessionId) return clientSessionId;

  let resolvedHubId = hubId;
  if (!resolvedHubId && deviceId) {
    const devSnap = await db.doc("devices/" + deviceId).get();
    if (devSnap.exists) {
      const data = devSnap.data() || {};
      if (data.hubId) resolvedHubId = data.hubId;
    }
  }
  if (!resolvedHubId) {
    throw new Error(
        "No hubId nor device.hubId provided; cannot resolve sessionId.",
    );
  }

  const hubSnap = await db.doc("hubs/" + resolvedHubId).get();
  const hData = hubSnap.exists ? hubSnap.data() || {} : {};
  const current = hData.currentSessionId || null;
  if (!current) {
    throw new Error(
        "No currentSessionId set for hub " + resolvedHubId + ".",
    );
  }
  return current;
}

/**
 * Resolve mapping for a device within a session.
 * Order: session overrides, then global devices (legacy supported).
 * @param {Object} p Params.
 * @param {string} p.sessionId Session id.
 * @param {string} p.deviceId Device id.
 * @param {string=} p.clientStudentId Student id from client.
 * @param {(string|number)=} p.clientSlotIndex Slot index from client.
 * @return {Promise<Object>} Resolves to
 *     {studentId: (string|null), slotIndex: (string|null)}.
 */
async function resolveMapping(p) {
  const sessionId = p.sessionId;
  const deviceId = p.deviceId;
  const clientStudentId = p.clientStudentId;
  const clientSlotIndex = p.clientSlotIndex;

  let studentId = clientStudentId || null;
  let slotIndex = normalizeSlot(clientSlotIndex);

  // 1) session-scoped overrides
  if (!studentId || !slotIndex) {
    const ovRef = db.doc(
        "sessions/" + sessionId + "/deviceOverrides/" + deviceId,
    );
    const ovSnap = await ovRef.get();
    if (ovSnap.exists) {
      const ov = ovSnap.data() || {};
      const noExp = !ov.expiresAt || ov.expiresAt.toMillis() > Date.now();
      if (noExp) {
        if (!studentId && ov.studentId) studentId = ov.studentId;
        const ovSlot = normalizeSlot(ov.slotIndex);
        if (!slotIndex && ovSlot) slotIndex = ovSlot;
      }
    }
  }

  // 2) global devices
  if (!studentId || !slotIndex) {
    const devRef = db.doc("devices/" + deviceId);
    const devSnap = await devRef.get();
    if (devSnap.exists) {
      const dev = devSnap.data() || {};
      if (!studentId && dev.studentId) studentId = dev.studentId;
      const dSlot = normalizeSlot(dev.slotIndex);
      if (!slotIndex && dSlot) slotIndex = dSlot;

      // legacy support
      if (!studentId && dev.ownerStudentId) studentId = dev.ownerStudentId;
      const oldSlot = normalizeSlot(dev.ownerSlotIndex);
      if (!slotIndex && oldSlot) slotIndex = oldSlot;
    }
  }

  return {
    studentId: studentId || null,
    slotIndex: slotIndex || null,
  };
}

/**
 * HTTPS endpoint for Flic hub button events.
 * Body must include: deviceId, clickType, eventId.
 * hubId is recommended; otherwise device.hubId can be used.
 */
exports.receiveButtonEventV2 = onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).send("Only POST");
    }

    let body;
    try {
      body = typeof req.body === "string" ?
        JSON.parse(req.body) :
        (req.body || {});
    } catch (e) {
      console.log("Invalid JSON:", String(e));
      return res.status(400).send("Invalid JSON");
    }

    const hubId = body.hubId;
    const deviceId = body.deviceId;
    const clickType = body.clickType;
    const eventId = body.eventId;
    // const hubTs = body.hubTs;
    const clientSessionId = body.sessionId;
    const clientStudentId = body.studentId;
    const clientSlotIndex = body.slotIndex;
    const source = body.source;

    if (!deviceId || !clickType || !eventId) {
      return res
          .status(400)
          .send("deviceId, clickType, eventId are required.");
    }

    let sessionId;
    try {
      sessionId = await resolveSessionId({
        hubId: hubId,
        deviceId: deviceId,
        clientSessionId: clientSessionId,
      });
    } catch (e) {
      return res.status(400).send(String(e));
    }

    const evRef = db.doc(
        "sessions/" + sessionId + "/events/" + eventId,
    );

    // idempotent create
    let created = false;
    const rawHubTs = body.hubTs;

    // 안전한 숫자 변환
    const hubTsNum =
      typeof rawHubTs === "number" && Number.isFinite(rawHubTs) ?
        rawHubTs :
        (typeof rawHubTs === "string" && /^\d+$/.test(rawHubTs) ?
            Number(rawHubTs) :
            Date.now());

    try {
      await evRef.create({
        hubId: hubId || null,
        sessionId,
        deviceId,
        clickType,
        eventId,
        hubTs: hubTsNum, // ← 반드시 숫자(ms)
        ts: admin.firestore.FieldValue.serverTimestamp(),
        source: source || "hub-flic2",
      });
      created = true;
      console.log("event created:", evRef.path);
    } catch (e) {
      const code = e && e.code;
      if (code === 6 || code === "already-exists") {
        console.log("duplicate event:", evRef.path);
      } else {
        throw e;
      }
    }

    const mapping = await resolveMapping({
      sessionId: sessionId,
      deviceId: deviceId,
      clientStudentId: clientStudentId,
      clientSlotIndex: clientSlotIndex,
    });

    await evRef.set(
        {
          studentId: mapping.studentId,
          slotIndex: mapping.slotIndex,
        },
        {merge: true},
    );

    if (created && mapping.studentId && mapping.slotIndex) {
      const nowTs = admin.firestore.Timestamp.now();
      const statsRef = db.doc(
          "sessions/" + sessionId + "/studentStats/" + mapping.studentId,
      );
      const totalRef = db.doc(
          "sessions/" + sessionId + "/stats/summary",
      );

      await db.runTransaction(async (tx) => {
        const inc = admin.firestore.FieldValue.increment(1);
        const s = {};
        s.total = inc;
        s["bySlot." + mapping.slotIndex + ".count"] = inc;
        s["bySlot." + mapping.slotIndex + ".lastTs"] = nowTs;
        s.lastAction = clickType;

        tx.set(statsRef, s, {merge: true});
        tx.set(totalRef, {total: inc}, {merge: true});
      });
    }

    await db.doc("devices/" + deviceId).set(
        {
          lastClickType: clickType,
          lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
          hubId: hubId || admin.firestore.FieldValue.delete(),
        },
        {merge: true},
    );

    return res.status(200).send(
      created ? "event created + aggregated" : "duplicate event (ok)",
    );
  } catch (err) {
    console.error("receiveButtonEventV2 error:", err);
    return res.status(500).send(String(err));
  }
});
