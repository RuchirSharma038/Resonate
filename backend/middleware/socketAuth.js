import admin from "../config/firebase.js";

export default async (socket, next) => {
    try {
        const { token } = socket.handshake.auth;

        if (!token) {
            throw new Error("Missing token");
        }

        const decoded = await admin.auth().verifyIdToken(token);

        socket.userId = decoded.uid;
        socket.user = decoded;

        next();

    } catch (err) {
        next(new Error("Authentication error, Invalid firebase Token"));
    }
};