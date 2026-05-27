
import { ItunesClient } from "./itunesClient.js";

// LRU cache
const CACHE_TTL_MS = 5 * 60_000;   // 5 minutes
const CACHE_MAX_SIZE = 200;

class LRUCache {
    #store = new Map();
    #maxSize;

    constructor(maxSize) { this.#maxSize = maxSize; }

    get(key) {
        const entry = this.#store.get(key);
        if (!entry) return null;
        if (Date.now() > entry.expiresAt) {
            this.#store.delete(key);
            return null;
        }
        // Re insert to mark as recently used
        this.#store.delete(key);
        this.#store.set(key, entry);
        return entry.data;
    }

    set(key, data, ttlMs) {
        if (this.#store.has(key)) this.#store.delete(key);
        if (this.#store.size >= this.#maxSize) {
            // Evict least recently used 
            this.#store.delete(this.#store.keys().next().value);
        }
        this.#store.set(key, { data, expiresAt: Date.now() + ttlMs });
    }
}

const cache = new LRUCache(CACHE_MAX_SIZE);

//    MusicService

export class MusicService {
    
    static async search(query, limit) {
        const cacheKey = `${query.toLowerCase()}__${limit}`;
        const cached = cache.get(cacheKey);

        if (cached) {
            return { tracks: cached, cached: true };
        }

        // Fetch 3x from iTunes than we'll return
        const raw = await ItunesClient.search(query, Math.min(limit * 3, 50));

        
        const tracks = raw
            .map(shapeTrack)
            .filter(Boolean)
            .slice(0, limit);

        cache.set(cacheKey, tracks, CACHE_TTL_MS);
        return { tracks, cached: false };
    }
}

// Track shaping 
function shapeTrack(raw) {
    const previewUrl =
        typeof raw.previewUrl === "string" ? raw.previewUrl.trim() : "";
    if (!previewUrl) return null;

    // Upgrade artwork  
    const rawArtwork =
        typeof raw.artworkUrl100 === "string" ? raw.artworkUrl100 : null;
    const imageUrl = rawArtwork
        ? rawArtwork.replace("100x100bb", "300x300bb")
        : null;

    return {
        
        id: String(raw.trackId ?? raw.collectionId ?? Math.random()),
        title: raw.trackName ?? raw.collectionName ?? "Unknown",
        artist: raw.artistName ?? "Unknown",
        audioUrl: previewUrl,
        imageUrl,
        albumTitle: raw.collectionName ?? "",
        genre: raw.primaryGenreName ?? "",
        duration: Math.round((raw.trackTimeMillis ?? 0) / 1000),
        source: "itunes",
    };
}