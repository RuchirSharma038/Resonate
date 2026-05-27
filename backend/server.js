import express from "express";
import http from "http";
import { Server } from "socket.io";
import { cors, pingInterval, pingTimeout } from './config/socketConfig.js';
import { httpCorsMiddleware } from "./middleware/httpCors.js";
import authMiddleware from "./middleware/socketAuth.js";
import socketHandler from './sockets/socketHandler.js';
import musicRouter from "./routes/musicRouter.js";
import * as logger from "./utils/logger.js";

// App & Server
const app = express();
const server = http.createServer(app);


//HTTP middleware
app.use(express.json());
app.use(httpCorsMiddleware);

// REST routes
app.use("/api/music/", musicRouter);

// SOCKET.IO
const io = new Server(server, {
    cors,
    pingInterval,
    pingTimeout

}
);
io.use(authMiddleware);

socketHandler(io);


// Listen

const PORT = process.env.PORT || 3001;
server.listen(PORT, "0.0.0.0", () => {
    logger.info(`Server running on port ${PORT} [${process.env.NODE_ENV ?? "development"}]`);
});





