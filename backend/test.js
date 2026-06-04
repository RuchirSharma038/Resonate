import { createSession } from "./controller/sessionController.js";
import { SERVER } from "./constants/events.js";

const mockSocket = {
  userId: "test-user-id",
  emit: (event, data) => console.log("emit", event, data),
  join: (room) => console.log("join", room)
};

try {
  createSession(mockSocket);
} catch (err) {
  console.error("Error calling createSession:", err);
}
