# Resonate

**Resonate** is a real-time social audio application where multiple users can join a shared session and listen to the same audio **perfectly synchronized**.
The goal is to recreate the experience of **listening to music together remotely**.

## 🚀 Features (Planned / In Progress)

* Create a listening room
* Join rooms using a room code
* Real-time synchronized playback
* Host-controlled play / pause / seek
* Shared listening experience across devices
* Low-latency synchronization between users

## 🏗 Architecture

Resonate is built using a **client–server architecture**:

**Frontend (Mobile App)**

* Flutter
* Riverpod (state management)
* just_audio (audio playback)

**Backend**

* Node.js
* Express
* Socket.IO for real-time communication

**Storage**

* Firebase Storage (for audio files)
* Firebase services for metadata

## 📂 Project Structure

```text
resonate
│
├── resonate-app/        # Flutter mobile application
│
├── resonate-backend/    # Node.js + Socket.IO server
│
└── docs/                # Architecture notes and planning
```

## ⚡ How It Works (Concept)

1. A user creates a **room/session**.
2. Other users join using a **room code**.
3. The host controls playback.
4. Playback state (play/pause/timestamp) is synchronized via **Socket.IO**.
5. Clients fetch audio files and stay synced with the server state.

## 🛠 Tech Stack

**Frontend**

* Flutter
* Riverpod
* just_audio

**Backend**

* Node.js
* Express
* Socket.IO

**Cloud**

* Firebase Storage

## 📌 Goals

This project focuses on learning and demonstrating:

* Real-time systems
* WebSockets
* Distributed playback synchronization
* Mobile app architecture
* Full-stack system design

## 🔮 Future Improvements

* Better playback synchronization algorithms
* Song queues and playlists
* User accounts and authentication
* Scalable backend infrastructure
* Public room discovery
* Chat inside rooms

## 📄 License

This project is currently for learning and experimentation.
