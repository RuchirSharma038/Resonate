const ITUNES_BASE = "https://itunes.apple.com/search";
const TIMEOUT_MS = 8_000;
const MAX_FETCH_LIMIT = 50;

export class ItunesClient {
    static async search(query, limit) {
        const url = new URL(ITUNES_BASE);
        url.searchParams.set("term", query);
        url.searchParams.set("media", "music");
        url.searchParams.set("entity", "song");
        url.searchParams.set("limit", String(Math.min(limit, MAX_FETCH_LIMIT)));

        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

        let response;
        try {
            response = await fetch(url.toString(), { signal: controller.signal });
        } catch (err) {
            const isTimeout = err.name === "AbortError";
            throw Object.assign(
                new Error(
                    isTimeout
                        ? "Music search timed out. Please try again."
                        : "Could not reach the music API."
                ),
                { statusCode: 502, code: isTimeout ? "TIMEOUT" : "NETWORK_ERROR" }
            );
        } finally {
            clearTimeout(timeoutId);
        }

        if (response.status === 429) {
            throw Object.assign(
                new Error("Music service is temporarily busy. Please try again shortly."),
                { statusCode: 429, code: "UPSTREAM_RATE_LIMITED" }
            );
        }

        if (!response.ok) {
            throw Object.assign(
                new Error(`Upstream API error: ${response.status}`),
                { statusCode: 502, code: "UPSTREAM_ERROR" }
            );
        }

        let body;
        try {
            body = await response.json();
        } catch {
            throw Object.assign(
                new Error("Received a malformed response from the music API."),
                { statusCode: 502, code: "PARSE_ERROR" }
            );
        }

        return Array.isArray(body.results) ? body.results : [];
    }
}