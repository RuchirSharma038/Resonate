const userToSocket = new Map();
const socketToUser = new Map();

function registerClient(socket) {
    if (!userToSockets.has(socket.userId)) {
        userToSockets.set(socket.userId, new Set());
    }
    userToSockets.get(socket.userId).add(socket.id);
    socketToUser.set(socket.id, socket.userId);


}

function removeClient(socket) {
    const userId = socketToUser.get(socket.id);
    if (userId) {
        const sockets = userToSockets.get(userId);
        if (sockets) {
            sockets.delete(socket.id);
            if (sockets.size === 0) userToSockets.delete(userId);
        }
    }
    socketToUser.delete(socket.id);
}

function getSocketId(userId) {
    const sockets = userToSockets.get(userId);
    return sockets ? [...sockets][0] : undefined;
}

export default {
    registerClient,
    removeClient,
    getSocketId
};