const IS_PRODUCTION = process.env.NODE_ENV === "production";

function getAllowedOrigins() {
    const raw = process.env.ALLOWED_ORIGINS ?? "";
    return raw
        .split(",")
        .map((o) => o.trim())
        .filter(Boolean);
}

function originValidator(origin, callback) {

    if (!origin) {
        callback(null, true);
        return;
    }

    // Allow local development
    if (origin.includes("localhost") || origin.includes("127.0.0.1")) {
        callback(null, true);
        return;
    }

    const allowed = getAllowedOrigins();

    if (allowed.includes(origin)) {
        callback(null, true);
    } else {
        callback(new Error(`CORS: origin "${origin}" is not allowed`), false);
    }
}

export const cors = {
    origin: IS_PRODUCTION ? originValidator : "*",
    methods: ["GET", "POST"]
};
export const pingTimeout = 20000;
export const pingInterval = 25000;