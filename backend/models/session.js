class Session {

  constructor(sessionId, hostUserId) {

    this.sessionId = sessionId;
    this.hostUserId = hostUserId;

    this.clients = new Map(); // userId -> socketId

    this.trackUrl = null;

    this.state = "stopped"; // playing | paused | stopped

    this.position = 0;

    this.startedAt = null;

    this.createdAt = Date.now();

  }

}

export default Session;


//Example track object
/*
session.track = {
  url: "https://youtube.com/watch?v=abc",
  title: "Blinding Lights",
  duration: 200,
}
*/