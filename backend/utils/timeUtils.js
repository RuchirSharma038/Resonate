function computeStartTime(){
    return Date.now()+1500;
}
function computePosition(now,startTime){
    return now-startTime;
}

export default{
    computeStartTime,
    computePosition
};