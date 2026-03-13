const sessions = {};

import { timeStamp } from "console";
import { randomBytes } from "crypto";

function generateSessionId() {
    do {
        id = randomBytes(3).toString("hex").toUpperCase();
    } while (sessions[id]);

    return id;
}

function createSession(socket) {
    const sessionId = generateSessionId();

    sessions[sessionId] = {
        host: socket.id,
        users: [socket.id],
        playbackState: {
            isPlaying: false,
            //lastUpdatedtimestamp: 0,

            url: null,
            title: null,

            startedAt: null,
            pausedAt: null



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
    //socket.emi


    return true;
}

function playSong(socket, data) {
    if (!sessions[sid]) {
        return null;
    }
    const url = data.url;
    const sid = data.sid;
    const hid = data.hid;
    if (sessions[sid].host !== hid) {
        return null;
    }
    sessions[sid].playbackState.isPlaying = true;
    sessions[sid].playbackState.url = url;
    sessions[sid].playbackState.title = data.title;

    sessions[sid].playbackState.startedAt = Date.now();
    return sessions[sid];



}
export default { createSession, joinSession, playSong };