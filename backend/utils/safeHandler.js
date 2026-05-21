import * as logger from "./logger.js";

function isPlainObject(value) {
    return (
        value !== null &&
        typeof value === "object" &&
        !Array.isArray(value)
    );
}

export function safeHandler(socket, fn) {
    return async (rawData) => {
        // Normalise
        const data = isPlainObject(rawData) ? rawData : {};

        if (!isPlainObject(rawData) && rawData !== undefined) {
            
            logger.error(
                `Malformed payload from ${socket.userId}:`,
                JSON.stringify(rawData)
            );
        }

        try {
            await fn(data);
        } catch (err) {
            logger.error(
                `Unhandled error in socket event handler for user ${socket.userId}:`,
                err
            );

            socket.emit("error_message", {
                message: "An internal error occurred. Please try again.",
            });
        }
    };
}
