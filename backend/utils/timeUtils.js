function computeStartTime(){
    return Date.now()+2000;
}
function computePosition(now,startTime){
    return now-startTime;
}

export default{
    computeStartTime,
    computePosition
};