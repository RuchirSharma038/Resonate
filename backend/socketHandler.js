import { createRoom, joinRoom, playSong } from "./sessionManager.js";


export default (io) => {
    io.on("connection", (socket) => {
        console.log("A user connected: ", socket.id);

        socket.on("create-room", () => {
            const roomId = createRoom(socket);
            socket.emit("room-created", roomId);
        });

        socket.on("join-room", (roomId) => {
            const success = joinRoom(socket, roomId);
            if (success) {
                socket.emit("room-joined", roomId);
            } else {
                socket.emit("room-not-found");
            }
        });

        socket.on("play-song", (data) => {
            const success = playSong(socket, data);
            if (success === null) {
                socket.emit("error, You are not the host");
            } else {
                //socket.emit("You are not a host or there might be an issue playing the song");
                socket.emit("new-song", {
                    url: success.playbackState.url,
                    startedAt: success.playbackState.startedAt,
                    title: success.playbackState.title

                });
            }

        });

        socket.on("disconnect", () => {
            console.log("User disconnected");
        })
    })
}