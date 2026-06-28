const RATE_LIMIT_MAX = 30;
const RATE_LIMIT_WINDOW_MS = 60_000;
const ipWindows = new Map();

// Sweep stale windows every minute
setInterval(() => {
    const cutoff = Date.now() - RATE_LIMIT_WINDOW_MS;
    for (const [ip, entry] of ipWindows.entries()) {
        if (entry.windowStart < cutoff) ipWindows.delete(ip);
    }
}, RATE_LIMIT_WINDOW_MS);

function isRateLimited(ip) {
    const now = Date.now();
    const entry = ipWindows.get(ip);
    if (!entry || now - entry.windowStart >= RATE_LIMIT_WINDOW_MS) {
        ipWindows.set(ip, { count: 1, windowStart: now });
        return false;
    }
    entry.count += 1;
    return entry.count > RATE_LIMIT_MAX;
}

export function httpRateLimiter(req, res, next) {
    // Check proxy headers first, then req.ip, then raw socket
    const rawForwarded = req.headers['x-forwarded-for'];
    const forwardedIp = typeof rawForwarded === 'string' ? rawForwarded.split(',')[0].trim() : null;
    
    const ip = forwardedIp ?? req.ip ?? req.socket?.remoteAddress ?? "unknown";
    if (isRateLimited(ip)) {
        return res.status(429).json({
            error: "Too many search requests. Please wait a moment.",
            code: "RATE_LIMITED",
        });
    }
    next();
}
