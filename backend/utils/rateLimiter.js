class TokenBucket {
   
    constructor(capacity, refillRate) {
        this.capacity = capacity;
        this.refillRate = refillRate;    // tokens / second
       
        this._buckets = new Map();
    }

    
    consume(userId) {
        const now = Date.now();
        let bucket = this._buckets.get(userId);

        if (!bucket) {
            // First time we see this user, give them a full bucket
            bucket = { tokens: this.capacity, lastRefill: now };
            this._buckets.set(userId, bucket);
        }

        const elapsed = (now - bucket.lastRefill) / 1000; // seconds
        bucket.tokens = Math.min(
            this.capacity,
            bucket.tokens + elapsed * this.refillRate
        );
        bucket.lastRefill = now;

        if (bucket.tokens < 1) {
            return false; 
        }

        bucket.tokens -= 1;
        return true;
    }

  
    remove(userId) {
        this._buckets.delete(userId);
    }
}


export const pingLimiter = new TokenBucket(10, 1);
export const playbackLimiter = new TokenBucket(5, 0.5);
export const sessionLimiter = new TokenBucket(3, 0.1);
export const queueLimiter = new TokenBucket(10, 2);


export function cleanupLimiters(userId) {
    pingLimiter.remove(userId);
    playbackLimiter.remove(userId);
    sessionLimiter.remove(userId);
    queueLimiter.remove(userId);
}