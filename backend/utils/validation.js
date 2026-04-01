import { SERVER } from "../constants/events.js";

function requireSession(socket,session) {
    if (!session) {
        socket.emit(SERVER.ERROR_MSG, {
            message: "Session does not exist"
        });
        return false;
    }
    return true;


}
function requireHost(socket, session) {
    if (socket.userId !== session.hostUserId) {
        socket.emit(SERVER.ERROR_MSG, {
            message: "Only host can perform this action"
        });
        return false;
    }
    return true;

}
const AUDIO_EXTENSIONS = /\.(mp3|wav|ogg|flac|aac|m4a|opus|webm)(\?|#|$)/i;

function requireValidUrl(socket, url) {
    if (typeof url !== "string" || url.trim() === "") {
        socket.emit(SERVER.ERROR_MSG, { message: "URL must be a non-empty string" });
        return false;
    }

    let parsed;
    try {
        parsed = new URL(url.trim());
    } catch {
        socket.emit(SERVER.ERROR_MSG, { message: "Invalid URL format" });
        return false;
    }

    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
        socket.emit(SERVER.ERROR_MSG, { message: "URL must use http or https" });
        return false;
    }

    if (!parsed.pathname || parsed.pathname === "/") {
        socket.emit(SERVER.ERROR_MSG, { message: "URL must point to a specific audio resource" });
        return false;
    }

    if (!AUDIO_EXTENSIONS.test(parsed.pathname + parsed.search)) {
        socket.emit(SERVER.ERROR_MSG, {
            message: "URL must point to a supported audio file (.mp3, .wav, .ogg, .flac, .aac, .m4a, .opus, .webm)"
        });
        return false;
    }

    return true;
}
export default {
    requireSession,
    requireHost,
    requireValidUrl
}