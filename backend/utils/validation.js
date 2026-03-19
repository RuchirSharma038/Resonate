function requireSession(session){
    if(!session){
        throw new Error("Session not found");
    }

    
}
function requireHost(socket,session){
    if(socket.userId !== session.hostUserId){
        throw new Error("Only host allowed");
    }

}
export default{
    requireSession,
    requireHost
}