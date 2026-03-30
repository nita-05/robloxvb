const models = require("../config/models");

/**
 * Optional small AI layer: adds HybridExt_* scripts only (names enforced server-side).
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {string[]} features
 * @param {object} mergedSummary { templateIds, scriptNames, assetCount }
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function generateHybridEnhancement(openai, prompt, features, mergedSummary, stripCodeFences, safeJsonParse) {
    const model = process.env.HYBRID_ENHANCE_MODEL || models.CHAT;
    const system = `You write small, safe Roblox Luau snippets as JSON only.

Return ONLY valid JSON:
{"scripts":[{"name":"HybridExt_BossPulse","parent":"ServerScriptService","className":"Script","source":"-- lua..."}],"message":"one line summary"}

Hard rules:
- 0 to 2 scripts only.
- Every name MUST start with exactly "HybridExt_".
- parent is either "ServerScriptService" or "StarterPlayerScripts".
- className is "Script" or "LocalScript" (match parent: Server → Script, client HUD → LocalScript).
- No loadstring, no HttpService, no getfenv/setfenv, no require of unknown IDs.
- Keep each script under ~60 lines, commented, and runnable in a blank place file that already has workspace.GeneratedGame.`;

    const user = JSON.stringify(
        {
            idea: String(prompt || "").slice(0, 1500),
            features: features || [],
            merged: mergedSummary || {},
        },
        null,
        0
    );

    const res = await openai.chat.completions.create({
        model,
        temperature: 0.5,
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
    const scriptsIn = Array.isArray(v.scripts) ? v.scripts : [];
    /** @type {object[]} */
    const scripts = [];
    for (const s of scriptsIn) {
        if (!s || typeof s.name !== "string" || !s.name.startsWith("HybridExt_")) continue;
        const parent = s.parent === "StarterPlayerScripts" ? "StarterPlayerScripts" : "ServerScriptService";
        const className = s.className === "LocalScript" ? "LocalScript" : "Script";
        const source = typeof s.source === "string" ? s.source : "";
        if (!source.trim()) continue;
        scripts.push({ name: s.name.slice(0, 80), parent, className, source });
        if (scripts.length >= 2) break;
    }

    return { scripts, message: typeof v.message === "string" ? v.message : "" };
}

module.exports = { generateHybridEnhancement };
