import { CLIENT } from "../constants/events.js";
import clientRegistry from "../services/clientRegistry.js";
import * as sessionController from "../controller/sessionController.js";
import * as logger from "../utils/logger.js";

export default function socketHandler(io) {

  io.on("connection", (socket) => {

    try {

      logger.info(`User connected: ${socket.userId}`);

      //Register User
      clientRegistry.registerClient(socket);

      /*
        SESSION EVENTS
      */

      socket.on(CLIENT.CREATE_SESSION, () => {
        sessionController.createSession(socket);
      });

      socket.on(CLIENT.JOIN_SESSION, (data) => {
        sessionController.joinSession(io, socket, data);
      });

      socket.on(CLIENT.LEAVE_SESSION, (data) => {
        sessionController.leaveSession(io, socket, data);
      });

      /*
        PING event
      */
      socket.on(CLIENT.PING, (data) => {
        sessionController.handlePing(socket, data);
      });


      /*
        PLAYBACK EVENTS (HOST ONLY)
      */

      socket.on(CLIENT.SET_URL, (data) => {
        sessionController.setUrl(io, socket, data);
      });

      socket.on(CLIENT.PLAY, (data) => {
        sessionController.play(io, socket, data);
      });

      socket.on(CLIENT.PAUSE, (data) => {
        sessionController.pause(io, socket, data);
      });

      socket.on(CLIENT.STOP, (data) => {
        sessionController.stop(io, socket, data);
      });


 // Queue Events
      socket.on(CLIENT.ADD_TO_QUEUE, (data) => {
        sessionController.addToQueue(io, socket, data);
      });

      socket.on(CLIENT.PLAY_NEXT, (data) => {
        sessionController.playNext(io, socket, data);
      });

      socket.on(CLIENT.REMOVE_FROM_QUEUE, (data) => {
        sessionController.removeFromQueue(io, socket, data);
      });

      // Seek Event
      socket.on(CLIENT.SEEK, (data) => {
        sessionController.seek(io, socket, data);
      });

      /*
        DISCONNECT HANDLING
      */

      socket.on("disconnect", (reason) => {

        logger.info(`User disconnected: ${socket.userId} (${reason})`);

        // handle leaving all sessions
        sessionController.handleDisconnect(io, socket);

        // remove socket mapping
        clientRegistry.removeClient(socket);

      });

      /*
        SOCKET ERROR HANDLING
      */

      socket.on("error", (err) => {
        logger.error(`Socket error for ${socket.userId}`, err);
      });

    } catch (err) {

      logger.error("Socket connection error", err);

      socket.emit("error", {
        message: "Internal server error"
      });

    }

  });

}