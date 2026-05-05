"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "asia-northeast3" });

function normalizeSlot(v) {
  if (v === null || v === undefined) return null;
  const s = String(v);
  return s === "1" || s === "2" ? s : null;
}

function normalizeDeviceType(v) {
  return String(v || "flic2").toLowerCase() === "duo" ? "duo" : "flic2";
}

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
  const current = hubSnap.exists
    ? hubSnap.data()?.currentSessionId || null
    : null;

  if (!current) throw new Error(`No currentSessionId set for hub ${hubId}.`);

  return current;
}

async function resolveMapping({
  hubId,
  deviceId,
  clientStudentId,
  clientSlotIndex,
  slotIndexFromHub,
  deviceType,
}) {
  let studentId = clientStudentId || null;
  let slotIndex = null;

  const isDuo = normalizeDeviceType(deviceType) === "duo";

  const dev = await db.doc(`hubs/${hubId}/devices/${deviceId}`).get();

  if (dev.exists) {
    const d = dev.data() || {};

    if (!studentId && d.studentId) {
      studentId = d.studentId;
    }

    if (isDuo) {
      slotIndex = normalizeSlot(slotIndexFromHub) || normalizeSlot(d.slotIndex);
    } else {
      slotIndex = normalizeSlot(clientSlotIndex) || normalizeSlot(d.slotIndex);
    }
  } else {
    if (isDuo) {
      slotIndex = normalizeSlot(slotIndexFromHub) || normalizeSlot(clientSlotIndex);
    } else {
      slotIndex = normalizeSlot(clientSlotIndex);
    }
  }

  if (!studentId || !slotIndex) {
    const g = await db.doc(`devices/${deviceId}`).get();

    if (g.exists) {
      const gd = g.data() || {};

      if (!studentId && gd.studentId) {
        studentId = gd.studentId;
      }

      if (!studentId && gd.ownerStudentId) {
        studentId = gd.ownerStudentId;
      }

      if (!slotIndex) {
        if (isDuo) {
          slotIndex =
            normalizeSlot(slotIndexFromHub) ||
            normalizeSlot(gd.slotIndex) ||
            normalizeSlot(gd.ownerSlotIndex);
        } else {
          slotIndex =
            normalizeSlot(clientSlotIndex) ||
            normalizeSlot(gd.slotIndex) ||
            normalizeSlot(gd.ownerSlotIndex);
        }
      }
    }
  }

  return {
    studentId: studentId || null,
    slotIndex: slotIndex || null,
  };
}

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

  const deviceType = normalizeDeviceType(body.deviceType);
  const slotIndexFromHub =
    deviceType === "duo" ? body.slotIndexFromHub : null;

  if (!hubId || !deviceId || !clickType || !eventId) {
    throw new Error("hubId, deviceId, clickType, eventId are required.");
  }

  const hubTs =
    typeof rawHubTs === "number" && Number.isFinite(rawHubTs)
      ? rawHubTs
      : typeof rawHubTs === "string" && /^\d+$/.test(rawHubTs)
        ? Number(rawHubTs)
        : Date.now();

  const sessionId = await resolveSessionId({
    hubId,
    deviceId,
    clientSessionId,
  });

  const mapping = await resolveMapping({
    hubId,
    deviceId,
    clientStudentId,
    clientSlotIndex,
    slotIndexFromHub,
    deviceType,
  });

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
        {
          lastSeenAt: nowTs,
          lastClickType: clickType,
          deviceType,
        },
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

        deviceType,
        source: body.source || null,
        buttonNumber:
          body.buttonNumber === undefined ? null : body.buttonNumber,
        slotIndexFromHub: normalizeSlot(slotIndexFromHub),
      },
      { merge: true }
    );

    tx.set(
      db.doc(`hubs/${hubId}/devices/${deviceId}`),
      {
        lastSeenAt: nowTs,
        lastClickType: clickType,
        deviceType,
      },
      { merge: true }
    );
  });
}

exports.receiveButtonEventUpdateOnly = onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).send("Only POST");
    }

    const body =
      typeof req.body === "string" ? JSON.parse(req.body) : req.body;

    await processSingleEvent(body);

    return res.status(200).send("liveByDevice updated");
  } catch (err) {
    console.error("receiveButtonEventUpdateOnly error:", err);
    return res.status(500).send(String(err));
  }
});