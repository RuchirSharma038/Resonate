import admin from "firebase-admin";
import serviceAccount from "../serviceAccKey/resonate-audio-sync-firebase-adminsdk-fbsvc-eb9f39ec92.json" with { type: "json" };

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

export default admin;