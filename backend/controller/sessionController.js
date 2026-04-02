// Functions TODO
// 1. create, join, leave
// 2. setUrl, play, pause, stop
// 3. handleDisconnect
// 4. ping

import { SERVER } from "../constants/events.js";
import clientRegistry from "../services/clientRegistry.js";
import { create, get, addClient, removeClient, removeSession, getAllSessionsOfUser } from "../services/sessionManager.js";
import validators from "../utils/validation.js";
import timeUtils from "../utils/timeUtils.js";
import idGenerator from "../utils/idGenerator.js";

function isStaleCommand(session, seq) {

    if (typeof seq !== "number") return false;
    if (seq <= session.lastCommandSeq) return true;
    session.lastCommandSeq = seq;
    return false;
}
//1. Create Session
export const createSession = (socket) => {
    // const { sessionId } = data;
    const sessionId = idGenerator.generateSessionId();
    let session = get(sessionId);
    if (session) {
        socket.emit("error", { message: "Session already exists" });
        return;
    }
    create(sessionId, socket.userId);
    socket.join(sessionId); //Join the room with sessionId provided

    //Now add the host into that session Map
    addClient(sessionId, socket.userId);

    //Now emit a socket event that session successfully created
    socket.emit(SERVER.SESSION_CREATED, {
        sessionId,
        hostId: socket.userId
    });


}


// 2. Join Session
export const joinSession = (io, socket, data) => {
    const { sessionId } = data;
    const session = get(sessionId);

    // First check if the session with sessionId exists or not
    validators.requireSession(socket, session);

    // Join user in that room
    socket.join(sessionId);

    //Add the client to map
    addClient(sessionId, socket.userId);

    //Emit a socket event that this particular user joined
    io.to(sessionId).emit(SERVER.USER_JOINED, {
        userId: socket.userId
    });

    // const livePosition = session.state === "playing" && session.startedAt
    //     ? session.position + (Date.now() - session.startedAt)
    //     : session.position;

    socket.emit(SERVER.SESSION_STATE, {
        url: session.trackUrl,
        state: session.state,
        position: session.position,
        startedAt: session.startedAt,
        hostId:session.hostUserId,
        //userId:socket.userId
    });



}

export function leaveSession(io, socket, data) {
    const { sessionId } = data;

    const session = get(sessionId);

    validators.requireSession(socket, session);

    // remove the clientId from sessionMap
    removeClient(sessionId, socket.userId);

    // Leave the room
    socket.leave(sessionId);

    // Emit the event of user left
    io.to(sessionId).emit(SERVER.USER_LEFT, {
        userId: socket.userId
    });

    //Handle the case when the host himself leaves
    handleHostLeave(io, session, socket.userId);

}


function handleHostLeave(io, session, leavingUserId) {
    if (session.hostUserId !== leavingUserId) {
        return;
    }
    const remainingUsers = [...session.clients.keys()];
    if (remainingUsers.length === 0) {
        removeSession(session.sessionId);
        return;
    }
    const newHost = remainingUsers[0];
    // Reset the sequence so the new host can start from 0/1
    session.lastCommandSeq = -1;
    session.hostUserId = newHost;
    io.to(session.sessionId).emit("host_changed", {
        hostId: newHost
    });
}

export const handleDisconnect = (io, socket) => {
    const sessions = getAllSessionsOfUser(socket.userId);
    sessions.forEach(session => {
        leaveSession(io, socket, { sessionId: session.sessionId });
    });
    clientRegistry.removeClient(socket);

}


export const setUrl = (io, socket, data) => {
    const { sessionId, url, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (!validators.requireValidUrl(socket, url)) return;

    if (isStaleCommand(session, seq)) return;


    session.trackUrl = url;
    session.state = "stopped";
    session.position = 0;
    session.startedAt = null;
    io.to(sessionId).emit(SERVER.SONG_UPDATED, { url: url });


}

export const play = (io, socket, data) => {
    const { sessionId, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (isStaleCommand(session, seq)) return;

    if (session.state === "playing") {
        return;
    }

    const startTime = timeUtils.computeStartTime();
    session.state = "playing";
    session.position = session.position ?? 0;
    session.startedAt = startTime;

    io.to(sessionId).emit(SERVER.PLAY_SONG, { startTime: startTime, position: session.position });


}

export const pause = (io, socket, data) => {
    const { sessionId, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (isStaleCommand(session, seq)) return;
    if (session.state !== "playing") {
        return;
    }

    const now = Date.now();

    let elapsed = 0;
    if (session.startedAt) {
        elapsed = Math.max(0, now - session.startedAt);
    }

    session.position += elapsed;

    session.state = "paused";
    session.startedAt = null;

    io.to(sessionId).emit(SERVER.PAUSE_SONG, {
        position: session.position,
        pauseTime: now
    });
}

export const stop = (io, socket, data) => {
    const { sessionId, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (isStaleCommand(session, seq)) return;

    session.state = "stopped";

    session.position = 0;
    session.startedAt = null;

    io.to(sessionId).emit(SERVER.STOP_SONG);
}

export const handlePing = (socket, data) => {
    const t1 = Date.now();

    if (!data || typeof data.id !== 'number') {
        return;
    }
    const { id, t0 } = data;
    const t2 = Date.now();

    socket.emit(SERVER.PONG, {
        id: id,
        t0: t0,
        t1: t1,
        t2: t2
    });
}







