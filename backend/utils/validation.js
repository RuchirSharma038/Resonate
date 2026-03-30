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
    if (socket.hostId !== session.userId) {
        socket.emit(SERVER.ERROR_MSG, {
            message: "Only host can perform this action"
        });
        return false;
    }
    return true;

}
export default {
    requireSession,
    requireHost
}