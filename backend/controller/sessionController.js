// Functions TODO
// 1. create, join, leave
// 2. setUrl, play, pause, stop
// 3. handleDisconnect
// 4. ping

import { SERVER } from "../constants/events.js";
import clientRegistry from "../services/clientRegistry.js";
import { create, get, addClient, removeClient, removeSession, getAllSessionsOfUser,addToQueueService, playNextTrack } from "../services/sessionManager.js";
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
        sessionId: session.sessionId,
        url: session.trackUrl,
        state: session.state,
        position: session.position,
        startedAt: session.startedAt,
        hostId:session.hostUserId,
        participants: Array.from(session.clients.keys()),

        queue: session.queue || []
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

export const seek = (io, socket, data) => {
    const { sessionId, position, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (isStaleCommand(session, seq)) return;
    if (typeof position !== "number" || position < 0) {
        socket.emit(SERVER.ERROR_MSG, { message: "Invalid seek position" });
        return;
    }
    session.position = position;
    if (session.state === "playing") {
        // Re-schedule playback with a fresh start time and the new position
        const startTime = timeUtils.computeStartTime();
        session.startedAt = startTime;
        io.to(sessionId).emit(SERVER.PLAY_SONG, {
            startTime,
            position: session.position
        });
    } else {
        // Paused/stopped — Move the slider only
        io.to(sessionId).emit(SERVER.SEEK_SONG, { position: session.position });
    }


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

export const addToQueue = (io, socket, data) => {
    const { sessionId, url } = data;
    const session = get(sessionId);

    // Ensure session exists and URL is valid
    if (!validators.requireSession(socket, session)) return;
    if (!validators.requireValidUrl(socket, url)) return;

    const updatedQueue = addToQueueService(sessionId, url);
    if (updatedQueue) {
        // Broadcast the new queue to everyone
        io.to(sessionId).emit(SERVER.QUEUE_UPDATED, updatedQueue);
    }
};

export const playNext = (io, socket, data) => {
    const { sessionId, seq } = data;
    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;
    if (!validators.requireHost(socket, session)) return; // Only host can skip/auto-play next!
    if (isStaleCommand(session, seq)) return;

    const nextData = playNextTrack(sessionId);

    if (nextData) {
        // Compute the precise synchronized start time for the new track
        const startTime = timeUtils.computeStartTime();
        session.startedAt = startTime;

        // 1. Tell everyone what the new song URL is
        io.to(sessionId).emit(SERVER.SONG_UPDATED, { url: nextData.trackUrl });

        // 2. Send the updated (shorter) queue
        io.to(sessionId).emit(SERVER.QUEUE_UPDATED, nextData.queue);

        // 3. Immediately command all devices to start playing from position 0
        io.to(sessionId).emit(SERVER.PLAY_SONG, { startTime: startTime, position: 0 });
    }
};
export const removeFromQueue = (io, socket, data) => {
    const { sessionId, url } = data;
    const session = get(sessionId);

    // 1. Ensure the session exists
    if (!validators.requireSession(socket, session)) return;
    if (!session.queue || session.queue.length === 0) return;

    // 2. Filter the deleted URL out of the queue array
    // (This keeps all songs that do NOT match the deleted URL)
    session.queue = session.queue.filter(trackUrl => trackUrl !== url);

    // 3. Broadcast the fresh, updated list back to every phone in the room
    // Note: Make sure SERVER.QUEUE_UPDATED is used (or just "queue_updated" if you hardcoded it)
    io.to(sessionId).emit(SERVER.QUEUE_UPDATED, session.queue);
};




