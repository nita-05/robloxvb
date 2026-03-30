const { getOrCachedRouting, computeTemplateRouting } = require("../services/hybridRouting");
const { mergeTemplates, normalizeTemplateOrder } = require("../services/templateLibrary");
const { generateHybridEnhancement } = require("../services/hybridEnhance");
const { buildAiOnlyMerged } = require("../services/hybridAiOnlyFallback");
const { buildPreMergeReport } = require("../services/templateMergeValidation");

const MAX_PROMPT = 2000;
const MAX_INSTRUCTION = 1200;

/**
 * @param {import("express").Express} app
 * @param {{ openai: import("openai").default, stripCodeFences: Function, safeJsonParse: Function }} deps
 */
module.exports = function registerHybridGame(app, deps) {
    const { openai, stripCodeFences, safeJsonParse } = deps;

    app.post("/analyze-prompt", async (req, res) => {
        try {
            const prompt = req.body?.prompt;
            if (typeof prompt !== "string" || !prompt.trim()) {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (prompt.length > MAX_PROMPT) {
                return res.status(400).json({ success: false, error: `prompt too long (max ${MAX_PROMPT})` });
            }

            const skipCache = req.body?.skipCache === true;
            const routing = skipCache
                ? { ...(await computeTemplateRouting(openai, prompt, stripCodeFences, safeJsonParse)), routingCached: false }
                : await getOrCachedRouting(openai, prompt, stripCodeFences, safeJsonParse);

            return res.json({
                success: true,
                mode: routing.mode,
                matchTier: routing.matchTier,
                reason: routing.reason,
                templates: routing.templates,
                features: routing.features,
                confidence: routing.confidencePercent,
                templateFitConfidence: routing.templateFitConfidence,
                routingCached: Boolean(routing.routingCached),
            });
        } catch (e) {
            console.error("[analyze-prompt]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });

    app.post("/merge-templates", async (req, res) => {
        try {
            const ids = req.body?.templates;
            if (!Array.isArray(ids)) {
                return res.status(400).json({ success: false, error: "templates must be an array" });
            }
            const norm = normalizeTemplateOrder(ids, []);
            const merged = mergeTemplates(norm.templates);
            const preMerge = buildPreMergeReport(norm.templates, merged.scripts);

            return res.json({
                success: true,
                templates: norm.templates,
                preMerge,
                merged: {
                    assets: merged.assets,
                    scripts: merged.scripts,
                },
            });
        } catch (e) {
            console.error("[merge-templates]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });

    app.post("/hybrid-generate", async (req, res) => {
        try {
            const prompt = req.body?.prompt;
            if (typeof prompt !== "string" || !prompt.trim()) {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (prompt.length > MAX_PROMPT) {
                return res.status(400).json({ success: false, error: `prompt too long (max ${MAX_PROMPT})` });
            }

            const wantEnhance =
                req.body?.enhance === true ||
                String(process.env.HYBRID_AI_LAYER || "")
                    .trim()
                    .toLowerCase() === "1";

            const forceAiOnly =
                req.body?.forceAiOnly === true || req.body?.aiFallback === true;

            const skipRoutingCache = req.body?.skipCache === true;
            const routing = skipRoutingCache
                ? { ...(await computeTemplateRouting(openai, prompt, stripCodeFences, safeJsonParse)), routingCached: false }
                : await getOrCachedRouting(openai, prompt, stripCodeFences, safeJsonParse);

            const forcedAiFallback = forceAiOnly && routing.mode !== "ai-only";

            if (routing.mode === "ai-only" || forcedAiFallback) {
                const ai = await buildAiOnlyMerged(openai, prompt, routing.features, stripCodeFences, safeJsonParse);
                const preMerge = buildPreMergeReport([], ai.scripts || []);
                const classifierRouting = forcedAiFallback
                    ? {
                          mode: routing.mode,
                          matchTier: routing.matchTier,
                          reason: routing.reason,
                          templates: routing.templates,
                          features: routing.features,
                          templateFitConfidence: routing.templateFitConfidence,
                          confidencePercent: routing.confidencePercent,
                      }
                    : undefined;
                return res.json({
                    success: true,
                    mode: "ai-only",
                    matchTier: "none",
                    reason: forcedAiFallback
                        ? "AI-only fallback requested; template merge skipped for this build."
                        : routing.reason,
                    classifierRouting,
                    forcedAiFallback: Boolean(forcedAiFallback),
                    aiEnhancement: forcedAiFallback
                        ? {
                              optional: true,
                              forced: false,
                              requested: wantEnhance,
                              applied: false,
                              aiOnlyFallbackUsed: true,
                              alwaysAvailable: true,
                          }
                        : {
                              optional: false,
                              forced: false,
                              requested: false,
                              applied: false,
                              aiOnlyBuild: true,
                              alwaysAvailable: true,
                          },
                    templates: [],
                    features: routing.features,
                    confidence: routing.confidencePercent,
                    templateFitConfidence: routing.templateFitConfidence,
                    routingCached: Boolean(routing.routingCached),
                    preMerge,
                    merged: {
                        assets: ai.assets,
                        scripts: ai.scripts,
                    },
                    assetKeywords: ai.assetKeywords || [],
                    aiLayer: false,
                    message: ai.message || "Built with AI-only fallback (assets + HybridAI_* scripts).",
                });
            }

            const norm = { templates: routing.templates, features: routing.features };
            const merged = mergeTemplates(norm.templates);
            const tier = routing.matchTier || (routing.mode === "template+ai" ? "partial" : "full");
            const forceAiLayer = tier === "partial";

            let extraScripts = [];
            let enhanceMessage = "";
            if (openai && (forceAiLayer || wantEnhance)) {
                const summary = {
                    templateIds: norm.templates,
                    scriptNames: merged.scripts.map((s) => s.name),
                    assetCount: merged.assets.length,
                };
                const enh = await generateHybridEnhancement(
                    openai,
                    prompt,
                    norm.features,
                    summary,
                    stripCodeFences,
                    safeJsonParse
                );
                extraScripts = enh.scripts || [];
                enhanceMessage = enh.message || "";
            }

            const allScripts = [...merged.scripts, ...extraScripts];
            const preMerge = buildPreMergeReport(norm.templates, allScripts);

            return res.json({
                success: true,
                mode: routing.mode,
                matchTier: tier,
                reason: routing.reason,
                templates: norm.templates,
                features: norm.features,
                confidence: routing.confidencePercent,
                templateFitConfidence: routing.templateFitConfidence,
                routingCached: Boolean(routing.routingCached),
                preMerge,
                merged: {
                    assets: merged.assets,
                    scripts: allScripts,
                },
                aiLayer: forceAiLayer || wantEnhance,
                aiEnhancement: {
                    optional: tier === "full",
                    forced: tier === "partial",
                    requested: wantEnhance,
                    applied: Boolean(forceAiLayer || wantEnhance),
                    alwaysAvailable: true,
                },
                message: enhanceMessage,
            });
        } catch (e) {
            console.error("[hybrid-generate]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });
};
