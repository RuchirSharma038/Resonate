import { CLIENT } from "../constants/events.js";
import clientRegistry from "../services/clientRegistry.js";
import * as sessionController from "../controller/sessionController.js";
import * as logger from "../utils/logger.js";
import { safeHandler } from "../utils/safeHandler.js";
import {
  pingLimiter,
  playbackLimiter,
  sessionLimiter,
  queueLimiter,
  cleanupLimiters,
} from "../utils/rateLimiter.js";
import { attachTokenRefreshHandler } from "../middleware/socketAuth.js";

function rateLimited(socket, limiter, fn) {
  return safeHandler(socket, (data) => {
    if (!limiter.consume(socket.userId)) {
      logger.error(`Rate limit hit for user ${socket.userId}`);
      socket.emit("error_message", {
        message: "You are sending requests too quickly. Please slow down.",
      });
      return;
    }
    return fn(data);
  });
}

export default function socketHandler(io) {
  io.on("connection", (socket) => {
    try {
      logger.info(`User connected: ${socket.userId}`);

      //Register User
      clientRegistry.registerClient(socket);
      attachTokenRefreshHandler(socket);

      /*
        SESSION EVENTS
      */

      socket.on(
        CLIENT.CREATE_SESSION,
        rateLimited(socket, sessionLimiter, () => {
          sessionController.createSession(socket);
        })
      );

      socket.on(
        CLIENT.JOIN_SESSION,
        rateLimited(socket, sessionLimiter, (data) => {
          sessionController.joinSession(io, socket, data);
        })
      );

      socket.on(
        CLIENT.LEAVE_SESSION,
        rateLimited(socket, sessionLimiter, (data) => {
          sessionController.leaveSession(io, socket, data);
        })
      );

      /*
        PING event
      */
      socket.on(
        CLIENT.PING,
        rateLimited(socket, pingLimiter, (data) => {
          sessionController.handlePing(socket, data);
        })
      );

      /*
        PLAYBACK EVENTS (HOST ONLY)
      */

      socket.on(
        CLIENT.SET_URL,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.setUrl(io, socket, data);
        })
      );

      socket.on(
        CLIENT.PLAY,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.play(io, socket, data);
        })
      );

      socket.on(
        CLIENT.PAUSE,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.pause(io, socket, data);
        })
      );

      socket.on(
        CLIENT.STOP,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.stop(io, socket, data);
        })
      );

      socket.on(
        CLIENT.SEEK,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.seek(io, socket, data);
        })
      );

      socket.on(
        CLIENT.SELECT_TRACK,
        rateLimited(socket, playbackLimiter, (data) => {
          sessionController.selectTrack(io, socket, data);
        })
      );

      // Queue Events
      socket.on(
        CLIENT.ADD_TO_QUEUE,
        rateLimited(socket, queueLimiter, (data) => {
          sessionController.addToQueue(io, socket, data);
        })
      );

      socket.on(
        CLIENT.PLAY_NEXT,
        rateLimited(socket, queueLimiter, (data) => {
          sessionController.playNext(io, socket, data);
        })
      );

      socket.on(
        CLIENT.REMOVE_FROM_QUEUE,
        rateLimited(socket, queueLimiter, (data) => {
          sessionController.removeFromQueue(io, socket, data);
        })
      );

      /*
        DISCONNECT HANDLING
      */

      socket.on("disconnect", (reason) => {
        logger.info(`User disconnected: ${socket.userId} (${reason})`);

        // handle leaving all sessions
        sessionController.handleDisconnect(io, socket);

        // remove socket mapping
        clientRegistry.removeClient(socket);

        // free per user tocken buckets
        cleanupLimiters(socket.userId);
      });

      /*
        SOCKET ERROR HANDLING
      */

      socket.on("error", (err) => {
        logger.error(`Socket error for ${socket.userId}`, err);
      });
    } catch (err) {
      logger.error("Socket connection error", err);

      socket.emit("error_message", {
        message: "Internal server error",
      });
    }
  });
}