function computeStartTime(){
    return Date.now()+500;
}
function computePosition(now,startTime){
    return now-startTime;
}

export default{
    computeStartTime,
    computePosition
};