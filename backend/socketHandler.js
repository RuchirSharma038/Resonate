const { createRoom, joinRoom } = require("./sessionManager.js");


module.exports = (io) => {
    io.on("connection", (socket) => {
        console.log("A user connected: ", socket.id);

        socket.on("create-room", () => {
            const roomId = createRoom(socket);
            socket.emit("room-created", roomId);
        });

        socket.on("join-room", (roomId) => {
            const success = joinRoom(socket, roomId);
            if(success){
                socket.emit("room-joined",roomId);
            }else{
                socket.emit("room-not-found");
            }
        });

        socket.on("disconnect", () => {
            console.log("User disconnected");
        })
    })
}