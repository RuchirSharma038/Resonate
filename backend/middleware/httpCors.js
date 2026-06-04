const IS_PRODUCTION = process.env.NODE_ENV === "production";

function getAllowedOrigins() {
    return (process.env.ALLOWED_ORIGINS ?? "")
        .split(",")
        .map((o) => o.trim())
        .filter(Boolean);
}

export function httpCorsMiddleware(req, res, next) {
    const origin = req.headers.origin;

    if (!origin) return next();

    if (!IS_PRODUCTION) {
        res.header("Access-Control-Allow-Origin", "*");
        return next();
    }

    const allowed = getAllowedOrigins();
    if (allowed.includes(origin) || origin.includes("localhost") || origin.includes("127.0.0.1")) {
        res.header("Access-Control-Allow-Origin", origin);
        res.header("Vary", "Origin");
    }

    next();
}