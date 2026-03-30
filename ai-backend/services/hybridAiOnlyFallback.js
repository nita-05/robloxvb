const models = require("../config/models");
const { extractAssetKeywords } = require("./openaiService");
const { matchAssetsFromKeywords, loadDataset } = require("./assetMatcher");

/**
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {string[]} features
 * @param {string[]} components
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function generateAiOnlyGameplayScripts(openai, prompt, features, components, stripCodeFences, safeJsonParse) {
    const model = process.env.HYBRID_AI_ONLY_MODEL || models.CHAT;
    const system = `You are a Roblox Luau engineer. The game idea does not use fixed templates — output a minimal playable scaffold.

Return ONLY JSON:
{"scripts":[{"name":"HybridAI_Server","parent":"ServerScriptService","className":"Script","source":"-- lua"}],"message":"summary"}

Rules:
- 1 to 3 scripts total.
- Every name MUST start with "HybridAI_".
- parent is "ServerScriptService" or "StarterPlayerScripts"; className is "Script" or "LocalScript".
- Reference workspace.GeneratedGame and subfolders Map, Assets, NPCs when needed (ensureFolder pattern).
- No loadstring, HttpService, getfenv, or require(assetId).
- Keep scripts short and commented (combined ~120 lines max).`;

    const user = JSON.stringify(
        {
            prompt: String(prompt || "").slice(0, 1800),
            features: features || [],
            components: components || [],
        },
        null,
        0
    );

    const res = await openai.chat.completions.create({
        model,
        temperature: 0.45,
        response_format: { type: "json_object" },
        messages: [
            { role: "system", content: system },
            { role: "user", content: user },
        ],
    });

    const raw = stripCodeFences(res.choices[0]?.message?.content || "");
    const parsed = safeJsonParse(raw);
    if (!parsed.ok) return { scripts: [], message: "" };

    const v = parsed.value || {};
    /** @type {object[]} */
    const out = [];
    for (const s of Array.isArray(v.scripts) ? v.scripts : []) {
        if (!s || typeof s.name !== "string" || !s.name.startsWith("HybridAI_")) continue;
        const parent = s.parent === "StarterPlayerScripts" ? "StarterPlayerScripts" : "ServerScriptService";
        const className = s.className === "LocalScript" ? "LocalScript" : "Script";
        const source = typeof s.source === "string" ? s.source : "";
        if (!source.trim()) continue;
        out.push({ name: s.name.slice(0, 80), parent, className, source });
        if (out.length >= 3) break;
    }
    return { scripts: out, message: typeof v.message === "string" ? v.message : "" };
}

/**
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {string[]} features
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function buildAiOnlyMerged(openai, prompt, features, stripCodeFences, safeJsonParse) {
    const { keywords, components } = await extractAssetKeywords(
        openai,
        { prompt, style: "realistic", regenerate: false },
        stripCodeFences,
        safeJsonParse
    );
    const featureStrs = (features || []).map((f) => String(f));
    const kw = [...keywords, ...featureStrs];
    const dataset = loadDataset();
    const { assets } = matchAssetsFromKeywords(kw, dataset, { limit: 12, maxCap: 15 });

    const { scripts, message } = await generateAiOnlyGameplayScripts(
        openai,
        prompt,
        featureStrs,
        components,
        stripCodeFences,
        safeJsonParse
    );

    return {
        assets,
        scripts,
        assetKeywords: keywords,
        message,
    };
}

module.exports = { buildAiOnlyMerged, generateAiOnlyGameplayScripts };
