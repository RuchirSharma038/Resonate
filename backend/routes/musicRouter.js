import { Router } from "express";
import { httpRateLimiter } from "../middleware/httpRateLimiter.js";
import * as musicController from "../controller/musicController.js";

const router = Router();

// GET /api/music/search?q=<query>&limit=<n>
router.get("/search", httpRateLimiter, musicController.searchMusic);

export default router;