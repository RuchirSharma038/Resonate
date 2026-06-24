import { MusicService } from "../services/musicService.js";
import * as logger from "../utils/logger.js";

export const searchMusic = async (req, res) => {
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

    // Call service
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
};
