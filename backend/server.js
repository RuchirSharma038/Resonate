import express from "express";
import http from "http";
import { Server } from "socket.io";
import { cors, pingInterval, pingTimeout } from './config/socketConfig.js';
import authMiddleware from "./middleware/socketAuth.js";
import socketHandler from './sockets/socketHandler.js';
import https from "https";
const app = express();
const server = http.createServer(app);

app.use(express.json());
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  next();
});


app.get('/api/music/search', (req, res) => {
  const query = req.query.q;
  if (!query) return res.status(400).json({ error: "Query is required" });

  const apiUrl = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=music&limit=20`;

  https.get(apiUrl, (apiRes) => {
    let data = '';
    apiRes.on('data', (chunk) => { data += chunk; });
    apiRes.on('end', () => {
      try {
        res.json(JSON.parse(data));
      } catch (e) {
        res.status(500).json({ error: "Failed to parse API response" });
      }
    });
  }).on('error', (err) => {
    res.status(500).json({ error: err.message });
  });
});
const io = new Server(server, {
    cors,
    pingInterval,
    pingTimeout

}
);
io.use(authMiddleware);

socketHandler(io);

server.listen(3001,'0.0.0.0', () => {
    console.log("Server is running...");
})





