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
    userToSocket.delete(socket.userId);
    socketToUser.delete(socket.id);
}

function getSocketId(userId) {
    return userToSocket.get(userId);
}

export default {
    registerClient,
    removeClient,
    getSocketId
};