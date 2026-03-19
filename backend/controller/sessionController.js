// Functions TODO
// 1. create, join, leave
// 2. setUrl, play, pause, stop
// 3. handleDisconnect

import { SERVER } from "../constants/events";
import clientRegistry from "../services/clientRegistry.js";
import { create, get, addClient, removeClient, removeSession, getAllSessionsOfUser } from "../services/sessionManager.js";
import validators from "../utils/validation.js";
import timeUtils from "../utils/timeUtils.js";
//1. Create Session
exports.createSession = (io, socket, data) => {
    const { sessionId } = data;
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
exports.joinSession = (io, socket, data) => {
    const { sessionId } = data;
    const session = get(sessionId);

    // First check if the session with sessionId exists or not
    validators.requireSession(session);

    // Join user in that room
    socket.join(sessionId);

    //Add the client to map
    addClient(sessionId, socket.userId);

    //Emit a socket event that this particular user joined
    io.to(sessionId).emit(SERVER.USER_JOINED, {
        userId: socket.userId
    });

    //Now send the present state of socket to the user
    socket.emit(SERVER.SESSION_STATE, {
        url: session.trackUrl,
        state: session.state,
        position: session.position,
        startedAt: session.startedAt,

    });

}

function leaveSession(io, socket, data) {
    const { sessionId } = data;

    const session = get(sessionId);

    validators.requireSession(session);

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
    if (session.hostId !== leavingUserId) {
        return;
    }
    const remainingUsers = [...session.clients];
    if (remainingUsers.length === 0) {
        removeSession(session.sessionId);
        return;
    }
    const newHost = remainingUsers[0];
    session.hostId = newHost;
    io.to(session.sessionId).emit("host_changed", {
        hostId: newHost
    });
}

exports.handleDisconnect = (io, socket) => {
    const sessions = getAllSessionsOfUser(socket.userId);
    sessions.forEach(sessionId => {
        leaveSession(io, socket, { sessionId });
    });
    clientRegistry.removeClient(socket);

}


exports.setUrl = (io, socket, data) => {
    const { sessionId, url } = data;
    const session = get(sessionId);
    validators.requireSession(session);

    validators.requireHost(socket, session);


    session.trackUrl = url;
    io.to(sessionId).emit(SERVER.SONG_UPDATED, { url: url });


}

exports.play = (io, socket, data) => {
    const { sessionId } = data;
    const session = get(sessionId);
    validators.requireSession(session);
    validators.requireHost(socket, session);

    const startTime = timeUtils.computeStartTime();
    session.state = "playing";
    session.startedAt = startTime;

    io.to(sessionId).emit(SERVER.PLAY_SONG, { startTime });


}

exports.pause = (io, socket, data) => {
    const { sessionId, position } = data;
    const session = get(sessionId);
    validators.requireSession(session);
    validators.requireHost(socket, session);


    session.state = "paused";
    session.position = position;

    io.to(sessionId).emit(SERVER.PAUSE_SONG, { position });
}

exports.stop = (io, socket, data) => {
    const { sessionId } = data;
    const session = get(sessionId);
    validators.requireSession(session);
    validators.requireHost(socket, session);

    session.state = "stopped";

    session.position = 0;
    session.startedAt = null;

    io.to(sessionId).emit(SERVER.STOP_SONG);
}
exports.leaveSession = leaveSession;






