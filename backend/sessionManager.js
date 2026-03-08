const sessions = {};

import { randomBytes } from "crypto";

function generateSessionId() {
    return randomBytes(3).toString("hex").toUpperCase();
}

function createSession(socket) {
    const sessionId = generateSessionId();

    sessions[sessionId] = {
        host: socket.id,
        users: [socket.id],
        playbackState: {
            isPlaying: false,
            timestamp: 0
        }

    };

    socket.join(sessionId);

    return sessionId;
}

function joinSession(socket, sessionId) {
    if (!sessions[sessionId]) return false;

    if (!sessions[sessionId].users.includes(socket.id)) {

        sessions[sessionId].users.push(socket.id);
    }
    socket.join(sessionId);

    return true;
}
export default { createSession, joinSession };