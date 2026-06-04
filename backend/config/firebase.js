import admin from "firebase-admin";
import { readFileSync } from "fs";

let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    // RENDER
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
    // LOCAL
    const fileUrl = new URL('../serviceAccKey/firebase-key.json', import.meta.url);
    serviceAccount = JSON.parse(readFileSync(fileUrl, "utf8"));
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

export default admin;