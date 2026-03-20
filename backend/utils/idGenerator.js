import { nanoid } from "nanoid";
import { get } from "../services/sessionManager.js";

function generateSessionId  () {
    let sessionId;
    do {
        sessionId = nanoid(8);
    } while (get(sessionId));
    return sessionId;
}

export default{generateSessionId};