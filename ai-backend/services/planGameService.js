const { getOrCachedRouting } = require("./hybridRouting");
const models = require("../config/models");

/**
 * Deep planner: uses classifier routing (cached) + structured expansion from OpenAI.
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any, error?: Error }} safeJsonParse
 */
async function buildGamePlan(openai, prompt, stripCodeFences, safeJsonParse) {
    const routing = await getOrCachedRouting(openai, prompt, stripCodeFences, safeJsonParse);

    const system = `You are the technical planning engine for a Roblox Studio plugin that builds games from text prompts.

Output ONLY valid JSON (no markdown, no code fences) with this exact shape:
{
  "features": ["string", ...],
  "assets": ["toolbox search phrase", ...],
  "steps": ["Step 1 ...", "Step 2 ..."],
  "script_requirements": ["checkpoint system", ...],
  "placement_strategy": "spread_obstacles_linearly"
}

Rules:
- You will receive classifier output: mode (template | template+ai | ai-only), matchTier (full | partial | none), reason (short classifier explanation), templates[], features[], confidence. Expand and refine features/assets/steps; do NOT change mode, matchTier, reason, or templates in your output (those are set server-side).
- features: 5–12 concise gameplay/art/social strings.
- assets: 6–14 concrete prop/map kit phrases for searching free models (not numeric IDs).
- steps: 4–8 ordered high-level steps: map/layout → environment → props/NPCs → scripts → playtest.
- script_requirements: systems to implement (AI, checkpoints, economy, UI).
- placement_strategy: one snake_case id (e.g. linear_checkpoint, hub_spoke, arena, grid).`;

    const ctx = {
        mode: routing.mode,
        matchTier: routing.matchTier,
        reason: routing.reason,
        templates: routing.templates,
        features: routing.features,
        templateFitConfidence: routing.templateFitConfidence,
        confidencePercent: routing.confidencePercent,
    };

    const model = process.env.PLAN_GAME_MODEL || models.PLANNER;

    const res = await openai.chat.completions.create({
        model,
        temperature: 0.35,
        response_format: { type: "json_object" },
        messages: [
            { role: "system", content: system },
            {
                role: "user",
                content:
                    `User prompt:\n${String(prompt || "")
                        .trim()
                        .slice(0, 2000)}\n\nClassifier JSON:\n${JSON.stringify(ctx, null, 0)}`,
            },
        ],
    });

    const raw = stripCodeFences(res.choices[0]?.message?.content || "");
    const parsed = safeJsonParse(raw);
    if (!parsed.ok) {
        const err = new Error("Planner returned non-JSON");
        /** @type {any} */ (err).cause = parsed.error;
        throw err;
    }

    const v = parsed.value || {};

    const featPlanner = Array.isArray(v.features) ? v.features.map((x) => String(x).trim()).filter(Boolean) : [];
    const mergedFeatures = [...new Set([...(routing.features || []).map(String), ...featPlanner])];

    const plan = {
        mode: routing.mode,
        matchTier: routing.matchTier,
        reason: routing.reason,
        templates: routing.templates,
        features: mergedFeatures.length ? mergedFeatures : routing.features,
        assets: Array.isArray(v.assets) ? v.assets.map((x) => String(x).trim()).filter(Boolean) : [],
        steps: Array.isArray(v.steps) ? v.steps.map((x) => String(x).trim()).filter(Boolean) : [],
        script_requirements: Array.isArray(v.script_requirements)
            ? v.script_requirements.map((x) => String(x).trim()).filter(Boolean)
            : [],
        placement_strategy:
            typeof v.placement_strategy === "string" && v.placement_strategy.trim()
                ? v.placement_strategy.trim()
                : "default",
    };

    if (plan.steps.length === 0) {
        plan.steps = [
            "Generate base map / spawn layout",
            "Apply environment & lighting",
            "Insert props and NPC placeholders",
            "Inject gameplay scripts",
            "Smoke test in Studio",
        ];
    }

    return {
        ...plan,
        routingCached: Boolean(routing.routingCached),
        plannerModel: model,
        templateFitConfidence: routing.templateFitConfidence,
        confidencePercent: routing.confidencePercent,
    };
}

module.exports = { buildGamePlan };
