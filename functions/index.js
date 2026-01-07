"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "asia-northeast3" });

// -----------------------------
// slot 정규화
// -----------------------------
function normalizeSlot(v) {
  if (v === null || v === undefined) return null;
  const s = String(v);
  return s === "1" || s === "2" ? s : null;
}

// -----------------------------
// 세션 해석
// -----------------------------
async function resolveSessionId({ hubId, deviceId, clientSessionId }) {
  if (clientSessionId) return clientSessionId;

  if (!hubId && deviceId) {
    const hubsSnap = await db.collection("hubs").get();
    for (const hub of hubsSnap.docs) {
      const devRef = db.doc(`hubs/${hub.id}/devices/${deviceId}`);
      const d = await devRef.get();
      if (d.exists) {
        hubId = hub.id;
        break;
      }
    }
  }

  if (!hubId) throw new Error("No hubId provided; cannot resolve sessionId.");

  const hubSnap = await db.doc(`hubs/${hubId}`).get();
  const current = hubSnap.exists ? (hubSnap.data()?.currentSessionId || null) : null;
  if (!current) throw new Error(`No currentSessionId set for hub ${hubId}.`);

  return current;
}

// -----------------------------
// 매핑 해석
// -----------------------------
async function resolveMapping({ hubId, deviceId, clientStudentId, clientSlotIndex }) {
  let studentId = clientStudentId || null;
  let slotIndex = normalizeSlot(clientSlotIndex);

  if (!studentId || !slotIndex) {
    const dev = await db.doc(`hubs/${hubId}/devices/${deviceId}`).get();
    if (dev.exists) {
      const d = dev.data() || {};
      if (!studentId && d.studentId) studentId = d.studentId;
      const s = normalizeSlot(d.slotIndex);
      if (!slotIndex && s) slotIndex = s;
    }
  }

  if (!studentId || !slotIndex) {
    const g = await db.doc(`devices/${deviceId}`).get();
    if (g.exists) {
      const gd = g.data() || {};
      if (!studentId && gd.studentId) studentId = gd.studentId;
      const s = normalizeSlot(gd.slotIndex);
      if (!slotIndex && s) slotIndex = s;
      if (!studentId && gd.ownerStudentId) studentId = gd.ownerStudentId;
      const os = normalizeSlot(gd.ownerSlotIndex);
      if (!slotIndex && os) slotIndex = os;
    }
  }

  return { studentId: studentId || null, slotIndex: slotIndex || null };
}

// ======================================================
// 🔥 기존 단일 이벤트 처리 로직 (그대로 분리)
// ======================================================
async function processSingleEvent(body) {
  const hubId = body.hubId;
  const deviceId = body.deviceId;
  const clickType = body.clickType;
  const eventId = body.eventId;
  const rawHubTs = body.hubTs;
  const seq = Number(body.seq || 0);
  const clientSessionId = body.sessionId;
  const clientStudentId = body.studentId;
  const clientSlotIndex = body.slotIndex;

  if (!hubId || !deviceId || !clickType || !eventId) {
    throw new Error("hubId, deviceId, clickType, eventId are required.");
  }

  const hubTs =
    typeof rawHubTs === "number" && Number.isFinite(rawHubTs)
      ? rawHubTs
      : (typeof rawHubTs === "string" && /^\d+$/.test(rawHubTs)
          ? Number(rawHubTs)
          : Date.now());

  const sessionId = await resolveSessionId({ hubId, deviceId, clientSessionId });
  const mapping = await resolveMapping({ hubId, deviceId, clientStudentId, clientSlotIndex });

  const liveRef = db.doc(`hubs/${hubId}/liveByDevice/${deviceId}`);

  await db.runTransaction(async (tx) => {
    const cur = await tx.get(liveRef);
    const nowTs = admin.firestore.Timestamp.now();

    let shouldUpdate = true;

    if (cur.exists) {
      const prev = cur.data() || {};
      const prevHubTs = typeof prev.lastHubTs === "number" ? prev.lastHubTs : -1;
      const prevSeq = typeof prev.lastSeq === "number" ? prev.lastSeq : -1;

      if (hubTs < prevHubTs) shouldUpdate = false;
      else if (hubTs === prevHubTs && seq <= prevSeq) shouldUpdate = false;
      if (prev.lastEventId === eventId) shouldUpdate = false;
    }

    if (!shouldUpdate) {
      tx.set(
        db.doc(`hubs/${hubId}/devices/${deviceId}`),
        { lastSeenAt: nowTs, lastClickType: clickType },
        { merge: true }
      );
      return;
    }

    tx.set(
      liveRef,
      {
        deviceId,
        sessionId,
        studentId: mapping.studentId,
        slotIndex: mapping.slotIndex,
        clickType,
        lastHubTs: hubTs,
        lastSeq: seq,
        lastEventId: eventId,
        updatedAt: nowTs,
      },
      { merge: true }
    );

    tx.set(
      db.doc(`hubs/${hubId}/devices/${deviceId}`),
      { lastSeenAt: nowTs, lastClickType: clickType },
      { merge: true }
    );
  });
}

// ======================================================
// 🔥 HTTP 엔드포인트 (배치 + 단일 지원)
// ======================================================
exports.receiveButtonEventUpdateOnly = onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") return res.status(405).send("Only POST");

    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;

    // 🔥 배치 이벤트
    if (body?.batched === true && Array.isArray(body.events)) {
      for (const ev of body.events) {
        await processSingleEvent(ev);
      }
      return res.status(200).send("batch processed");
    }

    // 🔥 단일 이벤트 (기존 방식)
    await processSingleEvent(body);
    return res.status(200).send("liveByDevice updated");

  } catch (err) {
    console.error("receiveButtonEventUpdateOnly error:", err);
    return res.status(500).send(String(err));
  }
});
