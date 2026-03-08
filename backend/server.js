const express = require("express");

const http = require("http");

const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "*"
    }
}
);

socketHandler(io);

server.listen(3001,()=>{
    console.log("Server is running...");
})
