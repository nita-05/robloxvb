const { extractAssetKeywords } = require("../services/openaiService");
const { matchAssetsFromKeywords, loadDataset } = require("../services/assetMatcher");

const MAX_PROMPT_LEN = 2000;
const MAX_CACHE_ENTRIES = 200;
/** @type {Map<string, { at: number, payload: object }>} */
const cache = new Map();

function cacheKey(body) {
    const p = String(body.prompt || "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ");
    const style = String(body.style || "realistic").toLowerCase() === "cartoon" ? "cartoon" : "realistic";
    const regen = body.regenerate ? "1" : "0";
    const maxA = Math.min(Math.max(parseInt(body.maxAssets, 10) || 10, 1), 15);
    return JSON.stringify({ p, style, regen, maxA });
}

function trimCache() {
    while (cache.size > MAX_CACHE_ENTRIES) {
        const first = cache.keys().next().value;
        if (first === undefined) break;
        cache.delete(first);
    }
}

/**
 * @param {import("express").Express} app
 * @param {{ openai: import("openai").default, stripCodeFences: Function, safeJsonParse: Function }} deps
 */
module.exports = function registerGenerateAssets(app, deps) {
    const { openai, stripCodeFences, safeJsonParse } = deps;

    app.post("/generate-assets", async (req, res) => {
        try {
            const promptRaw = req.body?.prompt;
            if (typeof promptRaw !== "string") {
                return res.status(400).json({ success: false, error: "prompt must be a string" });
            }
            const prompt = promptRaw.trim();
            if (!prompt) {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (prompt.length > MAX_PROMPT_LEN) {
                return res.status(400).json({
                    success: false,
                    error: `prompt too long (max ${MAX_PROMPT_LEN} chars)`,
                });
            }

            let maxAssets = parseInt(req.body?.maxAssets, 10);
            if (!Number.isFinite(maxAssets)) maxAssets = 10;
            maxAssets = Math.min(Math.max(maxAssets, 1), 15);

            const style = String(req.body?.style || "realistic").toLowerCase() === "cartoon" ? "cartoon" : "realistic";
            const regenerate = Boolean(req.body?.regenerate);

            const key = cacheKey({ ...req.body, prompt, style, regenerate, maxAssets });
            const hit = cache.get(key);
            if (hit) {
                return res.json(hit.payload);
            }

            const dataset = loadDataset();
            const { keywords, components } = await extractAssetKeywords(
                openai,
                { prompt, style, regenerate },
                stripCodeFences,
                safeJsonParse
            );

            const { assets } = matchAssetsFromKeywords(keywords, dataset, {
                limit: maxAssets,
                maxCap: 15,
            });

            const payload = {
                success: true,
                keywords,
                components,
                assets,
                style,
                cached: false,
            };

            cache.set(key, { at: Date.now(), payload: { ...payload, cached: true } });
            trimCache();

            return res.json(payload);
        } catch (e) {
            console.error("[generate-assets]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });
};
