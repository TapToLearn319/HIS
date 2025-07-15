// ▶ functions/index.js (Firebase Cloud Function 코드)
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.receiveButtonEvent = functions.https.onRequest(async (req, res) => {
  try {
    const {serialNumber, clickType, studentName} = req.body;
    if (!serialNumber || !clickType) {
      return res.status(400).send("serialNumber와 clickType이 필요합니다.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // 버튼별 서브컬렉션 'logs'에 이벤트 추가
    await admin.firestore()
        .collection("buttons") // 최상위 컬렉션
        .doc(serialNumber) // 버튼 고유 문서 ID
        .collection("logs") // 각 버튼별 로그 서브컬렉션
        .add({clickType, studentName, timestamp: now});

    return res.status(200).send("로그 저장 완료");
  } catch (error) {
    console.error("Function Error:", error);
    return res.status(500).send(error.toString());
  }
});
