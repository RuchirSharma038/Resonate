import admin from "../config/firebase.js";
import * as logger from "../utils/logger.js";

export const authMiddleware =  async (socket, next) => {
    try {
        const { token } = socket.handshake.auth;

        if (!token) {
            throw new Error("Missing token");
        }

        const decoded = await admin.auth().verifyIdToken(token);

        socket.userId = decoded.uid;
        socket.user = decoded;

        next();

    } catch (err) {
        next(new Error("Authentication error, Invalid firebase Token"));
    }
};


export function attachTokenRefreshHandler(socket) {
  socket.on("refresh_token", async (data) => {
    // data must be a plain object with a string token
    if (
      !data ||
      typeof data !== "object" ||
      typeof data.token !== "string" ||
      data.token.trim() === ""
    ) {
      logger.error(`refresh_token: malformed payload from ${socket.userId}`);
      socket.emit("token_refresh_result", {
        success: false,
        message: "Malformed token payload",
      });
      return;
    }
    try {
      const decoded = await admin.auth().verifyIdToken(data.token.trim());
 
      // Security check
      if (decoded.uid !== socket.userId) {
        logger.error(
          `refresh_token: UID mismatch. Original: ${socket.userId}, New: ${decoded.uid}`
        );
        // Force disconnect 
        socket.disconnect(true);
        return;
      }
 
      // Update the socket's credential in place
      socket.user = decoded;
      
      logger.info(`Token refreshed successfully for user ${socket.userId}`);
 
      socket.emit("token_refresh_result", { success: true });
    } catch (err) {
      logger.error(
        `refresh_token: verification failed for ${socket.userId}:`,
        err.message
      );
      
      socket.emit("token_refresh_result", {
        success: false,
        message: "Token verification failed. Please reconnect.",
      });
      socket.disconnect(true);
    }
  });
}

export default authMiddleware;