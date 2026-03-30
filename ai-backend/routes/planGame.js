const { buildGamePlan } = require("../services/planGameService");

const MAX_PROMPT = 2000;
const CACHE_MAX = parseInt(process.env.PLAN_GAME_CACHE_MAX || "150", 10) || 150;

/** @type {Map<string, object>} */
const planCache = new Map();

function cacheKey(prompt) {
    return String(prompt || "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ")
        .slice(0, MAX_PROMPT);
}

function trimCache() {
    while (planCache.size > CACHE_MAX) {
        const first = planCache.keys().next().value;
        if (first === undefined) break;
        planCache.delete(first);
    }
}

/**
 * @param {import("express").Express} app
 * @param {{ openai: import("openai").default, stripCodeFences: Function, safeJsonParse: Function }} deps
 */
module.exports = function registerPlanGame(app, deps) {
    const { openai, stripCodeFences, safeJsonParse } = deps;

    app.post("/plan-game", async (req, res) => {
        try {
            const prompt = req.body?.prompt;
            if (typeof prompt !== "string" || !prompt.trim()) {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (prompt.length > MAX_PROMPT) {
                return res.status(400).json({ success: false, error: `prompt too long (max ${MAX_PROMPT})` });
            }

            const skipCache = req.body?.skipCache === true;
            const key = cacheKey(prompt);
            if (!skipCache && planCache.has(key)) {
                return res.json({ success: true, ...planCache.get(key), cached: true });
            }

            const plan = await buildGamePlan(openai, prompt, stripCodeFences, safeJsonParse);
            const payload = { ...plan, cached: false };
            planCache.set(key, payload);
            trimCache();

            return res.json({ success: true, ...payload });
        } catch (e) {
            console.error("[plan-game]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });
};
