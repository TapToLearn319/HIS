// functions/index.js
"use strict";

const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "asia-northeast3" });

// "1" | "2" | null
function normalizeSlot(v) {
  if (v === null || v === undefined) return null;
  const s = String(v);
  return s === "1" || s === "2" ? s : null;
}

/**
 * hubs/{hubId}.currentSessionId 로 세션 결정
 * (clientSessionId가 있으면 우선)
 */
async function resolveSessionId({ hubId, deviceId, clientSessionId }) {
  if (clientSessionId) return clientSessionId;

  if (!hubId && deviceId) {
  // 허브 ID를 아직 모르면, 모든 hubs에서 이 deviceId를 탐색
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

/**
 * 허브 네임스페이스 하위에서 매핑 조회
 * 우선순위: hubs/{hubId}/deviceOverrides/{deviceId} → hubs/{hubId}/devices/{deviceId} → (글로벌 devices 레거시)
 */
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
    const dev = await db.doc(`hubs/${hubId}/devices/${deviceId}`).get();
    if (dev.exists) {
      const d = dev.data() || {};
      if (!studentId && d.studentId) studentId = d.studentId;
      const s = normalizeSlot(d.slotIndex);
      if (!slotIndex && s) slotIndex = s;
    }
  }

  // 레거시 글로벌
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

/**
 * 업데이트 전용 엔드포인트:
 * - hubs/{hubId}/liveByDevice/{deviceId} 한 문서만 최신성 비교 후 덮어쓰기
 * - 첫 이벤트면 문서 생성
 * - events/ 누적 생성 안 함
 */
exports.receiveButtonEventUpdateOnly = onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") return res.status(405).send("Only POST");

    // 입력 파싱
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    const hubId   = body.hubId;
    const deviceId= body.deviceId;
    const clickType = body.clickType;           // "click" | "double_click" | "hold"
    const eventId = body.eventId;               // 멱등 식별자
    const rawHubTs = body.hubTs;                // number | string
    const seq = Number(body.seq || 0);          // same-ms ordering
    const clientSessionId = body.sessionId;
    const clientStudentId = body.studentId;
    const clientSlotIndex = body.slotIndex;
    const source = body.source || "hub-flic2";

    if (!hubId || !deviceId || !clickType || !eventId) {
      return res.status(400).send("hubId, deviceId, clickType, eventId are required.");
    }

    // hubTs to number(ms)
    const hubTs =
      typeof rawHubTs === "number" && Number.isFinite(rawHubTs)
        ? rawHubTs
        : (typeof rawHubTs === "string" && /^\d+$/.test(rawHubTs) ? Number(rawHubTs) : Date.now());

    // 세션 해석
    const sessionId = await resolveSessionId({ hubId, deviceId, clientSessionId });

    // 매핑 해석(선택 필수 아님)
    const mapping = await resolveMapping({ hubId, deviceId, clientStudentId, clientSlotIndex });

    // 대상 문서: hubs/{hubId}/liveByDevice/{deviceId}
    const liveRef = db.doc(`hubs/${hubId}/liveByDevice/${deviceId}`);

    await db.runTransaction(async (tx) => {
      const cur = await tx.get(liveRef);
      const nowTs = admin.firestore.Timestamp.now();

      let shouldUpdate = true;
      let prev = null;

      if (cur.exists) {
        prev = cur.data() || {};
        const prevHubTs = typeof prev.lastHubTs === "number" ? prev.lastHubTs : -1;
        const prevSeq   = typeof prev.lastSeq === "number" ? prev.lastSeq : -1;

        // 최신성 비교: (hubTs, seq)가 더 크면 갱신
        if (hubTs < prevHubTs) shouldUpdate = false;
        else if (hubTs === prevHubTs && seq <= prevSeq) shouldUpdate = false;

        // 동일 이벤트 중복이면 무시
        if (prev.lastEventId && prev.lastEventId === eventId) shouldUpdate = false;
      }

      if (!shouldUpdate) {
        // 이미 더 최신 상태가 있거나 중복임 → 스킵
        tx.set(
          db.doc(`hubs/${hubId}/devices/${deviceId}`),
          {
            lastSeenAt: nowTs,
            lastClickType: clickType,
          },
          { merge: true }
        );
        return;
      }

      // 덮어쓸 데이터
      const next = {
        deviceId,
        sessionId,
        studentId: mapping.studentId,
        slotIndex: mapping.slotIndex,
        clickType,
        lastHubTs: hubTs,
        lastSeq: seq,
        lastEventId: eventId,
        updatedAt: nowTs,
        // pressCount: admin.firestore.FieldValue.increment(1), // 필요 시 주석 해제
      };

      // 문서 생성 or 갱신
      tx.set(liveRef, next, { merge: true });

      // (선택) 허브 네임스페이스의 디바이스 최신화
      tx.set(
        db.doc(`hubs/${hubId}/devices/${deviceId}`),
        {
          lastSeenAt: nowTs,
          lastClickType: clickType,
          // 매핑 고정 값을 유지하고 싶다면 studentId/slotIndex는 처음에만 세팅하도록 별도 로직을 두세요
        },
        { merge: true }
      );

      // (선택) 간단 합계가 필요하면 여기에 stats 갱신을 추가하세요
      // const totalRef = db.doc(`hubs/${hubId}/sessions/${sessionId}/stats/summary`);
      // tx.set(totalRef, { total: admin.firestore.FieldValue.increment(1) }, { merge: true });
    });

    return res.status(200).send("liveByDevice updated");
  } catch (err) {
    console.error("receiveButtonEventUpdateOnly error:", err);
    return res.status(500).send(String(err));
  }
});
