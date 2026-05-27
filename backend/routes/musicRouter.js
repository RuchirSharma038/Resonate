
import { Router } from "express";
import { MusicService } from "../services/musicService.js";
import * as logger from "../utils/logger.js";

const router = Router();

//  Per IP rate limiter


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

// GET /api/music/search?q=<query>&limit=<n>

router.get("/search", async (req, res) => {
    // Rate limit
    const ip = req.ip ?? req.socket?.remoteAddress ?? "unknown";
    if (isRateLimited(ip)) {
        return res.status(429).json({
            error: "Too many search requests. Please wait a moment.",
            code: "RATE_LIMITED",
        });
    }

    // Input validation 
    const rawQuery = req.query.q;
    if (typeof rawQuery !== "string" || rawQuery.trim().length === 0) {
        return res.status(400).json({
            error: "Query parameter 'q' is required.",
            code: "MISSING_QUERY",
        });
    }

    const query = rawQuery.trim().replace(/\s+/g, " ");
    if (query.length > 100) {
        return res.status(400).json({
            error: "Query must be 100 characters or fewer.",
            code: "QUERY_TOO_LONG",
        });
    }

    const rawLimit = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(rawLimit)
        ? Math.min(Math.max(rawLimit, 1), 20)
        : 20;

    // Delegate to service — router knows nothing about how results are fetched
    let result;
    try {
        result = await MusicService.search(query, limit);
    } catch (err) {
        logger.error("Music search failed:", err.message);
        const status = err.statusCode ?? 500;
        return res.status(status).json({
            error: err.message,
            code: err.code ?? "UPSTREAM_ERROR",
        });
    }

    if (result.tracks.length === 0) {
        return res.status(404).json({
            error: `No playable tracks found for "${query}".`,
            code: "NO_RESULTS",
        });
    }

    return res.json({
        results: result.tracks,
        count: result.tracks.length,
        cached: result.cached,
        query,
    });
});

export default router;