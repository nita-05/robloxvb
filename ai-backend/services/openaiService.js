const models = require("../config/models");

/**
 * @param {import("openai").default} openai
 * @param {{ prompt: string, style?: string, regenerate?: boolean }} input
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function extractAssetKeywords(openai, input, stripCodeFences, safeJsonParse) {
    const style = String(input.style || "realistic").toLowerCase() === "cartoon" ? "cartoon" : "realistic";
    const regenerate = Boolean(input.regenerate);

    const styleLine =
        style === "cartoon"
            ? "Prefer stylized, blocky, low-poly, colorful prop keywords (still generic Toolbox search terms)."
            : "Prefer realistic, detailed, architectural and interior keywords where appropriate.";

    const system = `You convert short Roblox scene descriptions into Toolbox search keyword phrases.
Break the idea into components (conceptual buckets) and emit English keyword phrases for 3D models/props.
${styleLine}

Return ONLY valid JSON with this shape:
{"components":["short bucket 1","short bucket 2"],"keywords":["two to four word phrase", "..."]}

Rules:
- 5 to 12 keywords total, each 2-5 words, no punctuation inside phrases.
- No Roblox asset IDs or numbers. No URLs. No Markdown.
- Keywords must be concrete object/setting terms (furniture, vehicles, buildings, nature, roads, lights, etc.).`;

    const userContent = regenerate
        ? `Produce a varied alternative set of keywords for the same scene (overlap OK but broaden coverage):\n${input.prompt}`
        : input.prompt;

    const model = process.env.ASSET_KEYWORD_MODEL || models.CHAT;

    const res = await openai.chat.completions.create({
        model,
        temperature: regenerate ? 0.85 : 0.35,
        response_format: { type: "json_object" },
        messages: [
            { role: "system", content: system },
            { role: "user", content: userContent },
        ],
    });

    const raw = stripCodeFences(res.choices[0]?.message?.content || "");
    const parsed = safeJsonParse(raw);
    if (!parsed.ok) {
        const err = new Error("Model returned non-JSON");
        /** @type {any} */ (err).cause = parsed.error;
        throw err;
    }

    const v = parsed.value;
    const keywords = Array.isArray(v.keywords) ? v.keywords.map((x) => String(x)) : [];
    const components = Array.isArray(v.components) ? v.components.map((x) => String(x)) : [];

    return {
        keywords: keywords.map((k) => k.trim()).filter(Boolean),
        components: components.map((k) => k.trim()).filter(Boolean),
    };
}

module.exports = { extractAssetKeywords };
