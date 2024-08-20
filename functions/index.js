const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendSessionNotifications = functions
  .runWith({
    timeoutSeconds: 540, // 9분 (스케줄 주기보다 약간 짧게)
    memory: '256MB',
    maxInstances: 5,
  })
  .pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const oneHourFromNow = new admin.firestore.Timestamp(now.seconds + 3600, now.nanoseconds);
      const oneDayFromNow = new admin.firestore.Timestamp(now.seconds + 86400, now.nanoseconds);

      const oneHourSessionsSnapshot = await admin.firestore()
        .collection("sessions")
        .where("startTime", ">", now)
        .where("startTime", "<=", oneHourFromNow)
        .where("oneHourNotificationSent", "==", false)
        .get();

      const oneDaySessionsSnapshot = await admin.firestore()
        .collection("sessions")
        .where("startTime", ">", oneDayFromNow)
        .where("startTime", "<=", new admin.firestore.Timestamp(oneDayFromNow.seconds + 86400, oneDayFromNow.nanoseconds))
        .where("oneDayNotificationSent", "==", false)
        .get();

      const sendNotificationPromises = [];

      for (const doc of oneHourSessionsSnapshot.docs) {
        sendNotificationPromises.push(sendNotification(doc, "oneHour"));
      }

      for (const doc of oneDaySessionsSnapshot.docs) {
        sendNotificationPromises.push(sendNotification(doc, "oneDay"));
      }

      await Promise.all(sendNotificationPromises);
      console.log(`알림 전송 완료. 1시간 전: ${oneHourSessionsSnapshot.size}, 1일 전: ${oneDaySessionsSnapshot.size}`);
    } catch (error) {
      console.error("sendSessionNotifications 함수에서 오류 발생:", error);
    }
  });

async function sendNotification(doc, type) {
  const session = doc.data();
  const userRef = admin.firestore().collection("users").doc(session.createdBy);

  try {
    const userDoc = await userRef.get();
    if (!userDoc.exists || !userDoc.data().fcmToken) {
      console.error(`유효하지 않은 사용자 또는 FCM 토큰 없음. 사용자 ID: ${session.createdBy}`);
      return;
    }

    const message = {
      notification: {
        title: "TRPG 세션 알림",
        body: type === "oneHour"
          ? `"${session.title}" 세션이 1시간 후에 시작됩니다!`
          : `"${session.title}" 세션이 내일 시작됩니다!`,
      },
      token: userDoc.data().fcmToken,
    };

    await admin.messaging().send(message);
    await doc.ref.update({
      [`${type === "oneHour" ? "oneHourNotificationSent" : "oneDayNotificationSent"}`]: true
    });
    console.log(`알림 전송 성공. 세션 ID: ${doc.id}, 타입: ${type}`);
  } catch (error) {
    console.error(`알림 전송 실패. 세션 ID: ${doc.id}, 타입: ${type}, 오류:`, error);
  }
}