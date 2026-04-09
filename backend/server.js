import express from "express";
import http from "http";
import { Server } from "socket.io";
import { cors, pingInterval, pingTimeout } from './config/socketConfig.js';
import authMiddleware from "./middleware/socketAuth.js";
import socketHandler from './sockets/socketHandler.js';

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
    cors,
    pingInterval,
    pingTimeout

}
);
io.use(authMiddleware);

socketHandler(io);

server.listen(3001,'0.0.0.0', () => {
    console.log("Server is running...");
})





