const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.receiveButtonEvent = functions.https
    .onRequest(async (req, res) => {
      try {
        const {serialNumber, clickType, studentName} = req.body;
        if (!serialNumber||!clickType) {
          return res
              .status(400)
              .send("serialNumber와 clickType이 필요합니다.");
        }
        const now = admin.firestore.FieldValue.serverTimestamp();
        const buttonRef = admin.firestore()
            .collection("buttons")
            .doc(serialNumber);

        await buttonRef.set(
            {
              lastClickType: clickType,
              lastUpdate: now,
            },
            {
              merge: true,
            },
        );
        await buttonRef
            .collection("logs")
            .add({
              clickType: clickType,
              studentName: studentName,
              timestamp: now,
            });

        return res
            .status(200)
            .send("로그 저장 및 부모 문서 upsert 완료");
      } catch (error) {
        console.error("Function Error:", error);
        return res
            .status(500)
            .send(error.toString());
      }
    });
