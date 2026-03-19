const express = require("express");
import { cors, pingInterval, pingTimeout } from './config/socketConfig.js';

const http = require("http");

const { Server } = require("socket.io");
import authMiddleware from "./middleware/socketAuth.js";

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

server.listen(3001, () => {
    console.log("Server is running...");
})





