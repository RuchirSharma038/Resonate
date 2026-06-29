import { SERVER } from "../constants/events.js";
import clientRegistry from "../services/clientRegistry.js";
import { create, get, addClient, removeClient, removeSession, getAllSessionsOfUser, addToQueueService, playNextTrack } from "../services/sessionManager.js";
import validators from "../utils/validation.js";
import timeUtils from "../utils/timeUtils.js";
import idGenerator from "../utils/idGenerator.js";
import { MAX_PARTICIPANTS, MAX_QUEUE_LENGTH } from "../constants/limits.js";

function isStaleCommand(session, seq) {

    if (typeof seq !== "number") return false;
    if (seq <= session.lastCommandSeq) return true;
    session.lastCommandSeq = seq;
    return false;
}

// 1. Create Session
export const createSession = (socket) => {

    const sessionId = idGenerator.generateSessionId();
    let session = get(sessionId);

    // If the session with that id already exists
    if (session) {
        socket.emit("error", { message: "Session already exists" });
        return;
    }


    //Create the session with sessionId and host user id = userId
    create(sessionId, socket.userId);

    // Host Join the room with sessionId provided
    socket.join(sessionId);

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
    if (!validators.requireSession(socket, session)) return;

    //Enforce the participants cap
    if (session.clients.size >= MAX_PARTICIPANTS) {
        socket.emit(SERVER.ERROR_MSG, {
            message: `Session is full (maximum ${MAX_PARTICIPANTS} participants).`,
        });
        return;
    }


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
        hostId: session.hostUserId,
        participants: Array.from(session.clients.keys()),

        queue: session.queue || []
    });



}

export function leaveSession(io, socket, data) {
    const { sessionId } = data;

    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;

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
    const sessionIds = getAllSessionsOfUser(socket.userId).map(
        (s) => s.sessionId
    );
    sessionIds.forEach((sessionId) => {
        leaveSession(io, socket, { sessionId });
    });
    //clientRegistry.removeClient(socket);

}


export const setUrl = (io, socket, data) => {
    const { sessionId, track, seq } = data;
    const session = get(sessionId);
    if (!validators.requireSession(socket, session)) {
        return;
    }
    if (!validators.requireHost(socket, session)) {
        return;
    }
    if (!track || !track.audioUrl || !validators.requireValidUrl(socket, track.audioUrl)) return;

    if (isStaleCommand(session, seq)) return;


    session.trackUrl = track.audioUrl;
    session.currentTrack = track;
    session.state = "stopped";
    session.position = 0;
    session.startedAt = null;
    io.to(sessionId).emit(SERVER.SONG_UPDATED, { track: track });


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

    const elapsed = session.startedAt
        ? Math.max(0, now - session.startedAt)
        : 0;

    session.position = session.position + elapsed;
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

        const startTime = timeUtils.computeStartTime();
        session.startedAt = startTime;
        io.to(sessionId).emit(SERVER.PLAY_SONG, {
            startTime,
            position: session.position
        });
    } else {

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
    const { sessionId, track } = data;
    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;
    if (!validators.requireHost(socket, session)) return;
    if (!track || !track.audioUrl || !validators.requireValidUrl(socket, track.audioUrl)) return;

    if ((session.queue?.length ?? 0) >= MAX_QUEUE_LENGTH) {
        socket.emit(SERVER.ERROR_MSG, {
            message: `Queue is full (maximum ${MAX_QUEUE_LENGTH} tracks). Remove a track before adding more.`,
        });
        return;
    }

    const updatedQueue = addToQueueService(sessionId, track);
    if (updatedQueue) {
        io.to(sessionId).emit(SERVER.QUEUE_UPDATED, updatedQueue);
    }
};

export const playNext = (io, socket, data) => {
    const { sessionId, seq } = data;
    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;
    if (!validators.requireHost(socket, session)) return; 
    if (isStaleCommand(session, seq)) return;

    const nextData = playNextTrack(sessionId);

    if (nextData) {
        const startTime = timeUtils.computeStartTime();

        session.state = "playing";
        session.startedAt = startTime;
        session.position = 0;
        session.currentTrack = nextData.track;

        io.to(sessionId).emit(SERVER.SONG_UPDATED, { track: nextData.track });
        io.to(sessionId).emit(SERVER.QUEUE_UPDATED, nextData.queue);
        io.to(sessionId).emit(SERVER.PLAY_SONG, { startTime: startTime, position: 0 });
    } else {
        session.state = "stopped";
        session.position = 0;
        session.startedAt = null;
        io.to(sessionId).emit(SERVER.STOP_SONG);
    }
};
import { removeFromQueueService } from "../services/sessionManager.js";

export const removeFromQueue = (io, socket, data) => {
    const { sessionId, trackId } = data;
    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;
    if (!session.queue || session.queue.length === 0) return;

    const updatedQueue = removeFromQueueService(sessionId, trackId);
    if (updatedQueue) {
        io.to(sessionId).emit(SERVER.QUEUE_UPDATED, updatedQueue);
    }
};
export const selectTrack = (io, socket, data) => {
    const { sessionId, track } = data;
    const session = get(sessionId);

    if (!validators.requireSession(socket, session)) return;
    if (!validators.requireHost(socket, session)) return;
    if (!track || !track.audioUrl) {
        socket.emit("error_message", { message: "Invalid track data" });
        return;
    }

    session.trackUrl = track.audioUrl;
    session.currentTrack = track;
    session.state = "stopped";
    session.position = 0;
    session.startedAt = null;

    socket.broadcast.to(sessionId).emit(SERVER.SELECT_TRACK, { track });
};



