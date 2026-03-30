const models = require("../config/models");

/**
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {string[]} knownTemplateIds
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any, error?: Error }} safeJsonParse
 */
async function analyzePromptForTemplates(openai, prompt, knownTemplateIds, stripCodeFences, safeJsonParse) {
    const model = process.env.HYBRID_ANALYZE_MODEL || models.CHAT;
    const allowed = knownTemplateIds.slice().sort();

    const system = `You classify Roblox game design prompts into hybrid builder templates and feature tags.

Known template ids (use ONLY these exact lowercase strings in "templates", 0 to 4 items, best order: base genre first, style/modifier second):
${JSON.stringify(allowed)}

Return ONLY JSON:
{"templates":["template_id", ...],"features":["short feature or mechanic", ...],"templateFitConfidence": 0.82,"reason":"one short sentence"}

reason: plain English (max ~240 chars). Explain WHY this confidence and template list fit the prompt — e.g. "Clear obby + checkpoint language; high match." or "Obby hinted but prompt mixes unrelated mechanics; partial fit." or "Space trading MMO; no strong overlap with allowed templates."

templateFitConfidence: number from 0 to 1 (you may use 0–100; server normalizes).
- HIGH (≥ ~0.7): prompt clearly matches obby, horror, racing, simulator, and/or tycoon patterns → server uses template-only unless user opts into extra AI.
- MEDIUM (roughly 0.45–0.69): partial fit or mixed genre → server uses template base plus a required AI hybrid layer.
- LOW (< ~0.45): niche or unrelated ideas — use few or zero templates and LOW confidence → server uses AI-only scaffold.

Rules:
- If the idea does NOT map well to allowed templates, return "templates": [] and a LOW templateFitConfidence.
- Use 3–10 concise feature strings either way (gameplay, economy, setting, etc.).
- Do not invent template ids outside the allowed list.`;

    const res = await openai.chat.completions.create({
        model,
        temperature: 0.25,
        response_format: { type: "json_object" },
        messages: [
            { role: "system", content: system },
            { role: "user", content: String(prompt || "").trim().slice(0, 2000) },
        ],
    });

    const raw = stripCodeFences(res.choices[0]?.message?.content || "");
    const parsed = safeJsonParse(raw);
    if (!parsed.ok) {
        const err = new Error("Analyzer returned non-JSON");
        /** @type {any} */ (err).cause = parsed.error;
        throw err;
    }

    const v = parsed.value || {};
    const rawTemplates = Array.isArray(v.templates) ? v.templates.map((x) => String(x).toLowerCase().trim()) : [];
    const rawFeatures = Array.isArray(v.features) ? v.features.map((x) => String(x).trim()).filter(Boolean) : [];

    const allowedSet = new Set(allowed);
    const templates = [];
    for (const t of rawTemplates) {
        if (allowedSet.has(t) && !templates.includes(t)) templates.push(t);
    }

    let templateFitConfidence;
    const c = v.templateFitConfidence;
    if (typeof c === "number" && !Number.isNaN(c)) {
        templateFitConfidence = c > 1 ? Math.min(1, c / 100) : Math.max(0, Math.min(1, c));
    }
    let confidence = v.confidence;
    if (typeof confidence === "number" && !Number.isNaN(confidence)) {
        confidence = confidence > 1 ? Math.min(1, confidence / 100) : Math.max(0, Math.min(1, confidence));
    } else {
        confidence = undefined;
    }

    let reason = typeof v.reason === "string" ? v.reason.trim() : "";
    if (reason.length > 280) {
        reason = reason.slice(0, 279) + "…";
    }

    return { templates, features: rawFeatures, templateFitConfidence, confidence, reason };
}

module.exports = { analyzePromptForTemplates };
