const userToSocket = new Map();
const socketToUser = new Map();

function registerClient(socket){
    userToSocket.set(socket.userId,socket.id);
    socketToUser.set(socket.id,socket.userId);


}

function removeClient(socket){
    userToSocket.delete(socket.userId);
    socketToUser.delete(socket.id);
}

function getSocketId(userId){
    return userToSocket(userId);
}

export default {
  registerClient,
  removeClient,
  getSocketId
};