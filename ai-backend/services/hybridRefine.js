const models = require("../config/models");

/**
 * @param {import("openai").default} openai
 * @param {{ prompt: string, instruction: string, templates: string[], features: string[], scriptNames: string[], generationMode?: string }} ctx
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function refineHybridGame(openai, ctx, stripCodeFences, safeJsonParse) {
    const model = process.env.HYBRID_REFINE_MODEL || models.CHAT;
    const system = `You refine a Roblox hybrid game based on the user's instruction.

generationMode will be "template" (prebuilt packs) or "ai-only" (fully AI-generated scaffold). Adapt suggestions accordingly.

Return ONLY JSON:
{
  "appendScripts": [{"name":"HybridExt_...","parent":"ServerScriptService","className":"Script","source":"-- lua"}],
  "addAssets": [12345],
  "removeScriptNames": ["HybridExt_OldOptional"],
  "message": "short summary"
}

Rules:
- appendScripts: max 2 items; each name MUST start with "HybridExt_".
- parent: "ServerScriptService" or "StarterPlayerScripts"; className "Script" or "LocalScript".
- No loadstring, HttpService, or obscure globals. Keep scripts small and commented.
- addAssets: optional array of numeric Roblox asset ids to suggest inserting (may be empty).
- removeScriptNames: optional; only HybridExt_* names the user added via prior refinement.`;

    const user = JSON.stringify(
        {
            originalPrompt: String(ctx.prompt || "").slice(0, 1500),
            instruction: String(ctx.instruction || "").slice(0, 1000),
            generationMode: ctx.generationMode === "ai-only" ? "ai-only" : "template",
            activeTemplates: ctx.templates || [],
            features: ctx.features || [],
            existingScriptNames: ctx.scriptNames || [],
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
    if (!parsed.ok) {
        const err = new Error("Refine model returned non-JSON");
        /** @type {any} */ (err).cause = parsed.error;
        throw err;
    }

    const v = parsed.value || {};
    const appendIn = Array.isArray(v.appendScripts) ? v.appendScripts : [];
    /** @type {object[]} */
    const appendScripts = [];
    for (const s of appendIn) {
        if (!s || typeof s.name !== "string" || !s.name.startsWith("HybridExt_")) continue;
        const parent = s.parent === "StarterPlayerScripts" ? "StarterPlayerScripts" : "ServerScriptService";
        const className = s.className === "LocalScript" ? "LocalScript" : "Script";
        const source = typeof s.source === "string" ? s.source : "";
        if (!source.trim()) continue;
        appendScripts.push({ name: s.name.slice(0, 80), parent, className, source });
        if (appendScripts.length >= 2) break;
    }

    const addAssets = [];
    if (Array.isArray(v.addAssets)) {
        for (const a of v.addAssets) {
            const id = typeof a === "string" ? parseInt(a, 10) : Number(a);
            if (Number.isFinite(id) && id > 0) addAssets.push(id);
        }
    }

    const removeScriptNames = [];
    if (Array.isArray(v.removeScriptNames)) {
        for (const n of v.removeScriptNames) {
            if (typeof n === "string" && n.startsWith("HybridExt_")) removeScriptNames.push(n.slice(0, 80));
        }
    }

    return {
        appendScripts,
        addAssets,
        removeScriptNames,
        message: typeof v.message === "string" ? v.message : "",
    };
}

module.exports = { refineHybridGame };
