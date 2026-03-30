import Session from "../models/session.js";

const sessions = new Map();

export const create=(sessionId,hostUserId)=>{
    const session = new Session(sessionId,hostUserId);
    sessions.set(sessionId,session);
    return session;
}

export const get=(sessionId)=>{
    
    return sessions.get(sessionId);
}

export const addClient=(sessionId,userId)=>{
    const session = sessions.get(sessionId);
    if(!session) return;

    session.clients.set(userId,true);
}
export const removeClient=(sessionId,userId)=>{
    const session = sessions.get(sessionId);
    if(!session)return;
    session.clients.delete(userId);
}

export const removeSession=(sessionId)=>{
    sessions.delete(sessionId);
}

export const getAllSessionsOfUser=(userId)=>{
    const result =[];
    for(const [sessionId,session] of sessions.entries()){
        if(session.clients.has(userId)){
            result.push(session);
        }
    }
    return result;
}





