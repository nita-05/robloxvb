const { getOrCachedRouting, computeTemplateRouting } = require("../services/hybridRouting");
const { mergeTemplates, normalizeTemplateOrder } = require("../services/templateLibrary");
const { generateHybridEnhancement } = require("../services/hybridEnhance");
const { refineHybridGame } = require("../services/hybridRefine");
const { buildAiOnlyMerged } = require("../services/hybridAiOnlyFallback");
const { runGenerationPipeline } = require("../services/generationPipeline");
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

    app.post("/pipeline-generate", async (req, res) => {
        try {
            const prompt = req.body?.prompt;
            if (typeof prompt !== "string" || !prompt.trim()) {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (prompt.length > MAX_PROMPT) {
                return res.status(400).json({ success: false, error: `prompt too long (max ${MAX_PROMPT})` });
            }

            const result = await runGenerationPipeline(
                openai,
                prompt,
                {
                    wantEnhance: req.body?.enhance === true,
                    alwaysRefine: req.body?.alwaysRefine !== false,
                    refineInstruction: typeof req.body?.refineInstruction === "string" ? req.body.refineInstruction : "",
                    skipCache: req.body?.skipCache === true,
                    forceAiOnly: req.body?.forceAiOnly === true || req.body?.aiFallback === true,
                },
                stripCodeFences,
                safeJsonParse
            );

            const applied = Boolean(result.forcedAiFallback);

            return res.json({
                success: true,
                mode: applied ? "ai-only" : result.routing.mode,
                matchTier: applied ? "none" : result.routing.matchTier,
                reason: applied ? result.appliedReason : result.routing.reason,
                templates: applied ? [] : result.routing.templates,
                features: result.routing.features,
                confidence: result.routing.confidencePercent,
                templateFitConfidence: result.routing.templateFitConfidence,
                routingCached: Boolean(result.routing.routingCached),
                classifierRouting: result.classifierRouting,
                forcedAiFallback: result.forcedAiFallback,
                aiEnhancement: result.aiEnhancement,
                preMerge: result.preMerge,
                mergedFinal: result.mergedFinal,
                refinement: result.refinement,
                recheckRouting: result.recheckRouting
                    ? {
                          mode: result.recheckRouting.mode,
                          matchTier: result.recheckRouting.matchTier,
                          reason: result.recheckRouting.reason,
                          templates: result.recheckRouting.templates,
                          features: result.recheckRouting.features,
                          confidence: result.recheckRouting.confidencePercent,
                          templateFitConfidence: result.recheckRouting.templateFitConfidence,
                      }
                    : null,
                smartLoopHint: result.smartLoopHint,
                recheckCyclesUsed: result.recheckCyclesUsed,
                recheckCycleLimit: result.recheckCycleLimit,
                recheckHistory: result.recheckHistory || [],
                assetKeywords: result.assetKeywords || [],
                pipeline: result.pipeline,
                message: result.message || "",
            });
        } catch (e) {
            console.error("[pipeline-generate]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });

    app.post("/refine-game", async (req, res) => {
        try {
            const prompt = req.body?.prompt;
            const instruction = req.body?.instruction;
            if (typeof prompt !== "string") {
                return res.status(400).json({ success: false, error: "prompt is required" });
            }
            if (typeof instruction !== "string" || !instruction.trim()) {
                return res.status(400).json({ success: false, error: "instruction is required" });
            }
            if (instruction.length > MAX_INSTRUCTION) {
                return res.status(400).json({ success: false, error: `instruction too long (max ${MAX_INSTRUCTION})` });
            }

            const templates = Array.isArray(req.body?.templates) ? req.body.templates.map(String) : [];
            const features = Array.isArray(req.body?.features) ? req.body.features.map(String) : [];
            const scriptNames = Array.isArray(req.body?.scriptNames) ? req.body.scriptNames.map(String) : [];
            const generationMode = req.body?.generationMode === "ai-only" ? "ai-only" : "template";

            const preferTemplateMerge = req.body?.preferTemplateMerge !== false;
            const skipRoutingCache = req.body?.skipCache === true;

            const inst = instruction.trim();
            const combinedForRouting = `${String(prompt).slice(0, 1500)}\n\nRefinement request:\n${inst}`.slice(0, MAX_PROMPT);

            /**
             * After initial generation, re-detect templates from (original prompt + refinement).
             * If templates match with enough confidence → try merge; if non-empty → done.
             * Otherwise → AI refinement (HybridExt_*).
             */
            if (preferTemplateMerge) {
                const routing = skipRoutingCache
                    ? { ...(await computeTemplateRouting(openai, combinedForRouting, stripCodeFences, safeJsonParse)), routingCached: false }
                    : await getOrCachedRouting(openai, combinedForRouting, stripCodeFences, safeJsonParse);

                const tier = routing.matchTier || (routing.mode === "template" ? "full" : routing.mode === "template+ai" ? "partial" : "none");

                if (tier === "full" && Array.isArray(routing.templates) && routing.templates.length > 0) {
                    const merged = mergeTemplates(routing.templates);
                    const hasScripts = Array.isArray(merged.scripts) && merged.scripts.length > 0;
                    const hasAssets = Array.isArray(merged.assets) && merged.assets.length > 0;
                    if (hasScripts || hasAssets) {
                        return res.json({
                            success: true,
                            path: "template_merge",
                            message:
                                "Strong template match after refine — merged template pack applied server-side; inject in Studio.",
                            routing: {
                                mode: routing.mode,
                                matchTier: tier,
                                reason: routing.reason,
                                templates: routing.templates,
                                features: routing.features,
                                confidence: routing.confidencePercent,
                                confidencePercent: routing.confidencePercent,
                                templateFitConfidence: routing.templateFitConfidence,
                                routingCached: Boolean(routing.routingCached),
                            },
                            merged: {
                                assets: merged.assets,
                                scripts: merged.scripts,
                            },
                        });
                    }
                }

                if (tier === "partial" && Array.isArray(routing.templates) && routing.templates.length > 0) {
                    const merged = mergeTemplates(routing.templates);
                    const hasScripts = Array.isArray(merged.scripts) && merged.scripts.length > 0;
                    const hasAssets = Array.isArray(merged.assets) && merged.assets.length > 0;
                    if (hasScripts || hasAssets) {
                        const refined = await refineHybridGame(
                            openai,
                            {
                                prompt: prompt.slice(0, MAX_PROMPT),
                                instruction: inst,
                                templates: routing.templates,
                                features: routing.features,
                                scriptNames: merged.scripts.map((s) => s.name),
                                generationMode: "template",
                            },
                            stripCodeFences,
                            safeJsonParse
                        );
                        return res.json({
                            success: true,
                            path: "template_hybrid_refine",
                            message:
                                refined.message ||
                                "Partial template match — base pack plus AI refinement (HybridExt_*); inject merged then append scripts.",
                            routing: {
                                mode: routing.mode,
                                matchTier: tier,
                                reason: routing.reason,
                                templates: routing.templates,
                                features: routing.features,
                                confidence: routing.confidencePercent,
                                confidencePercent: routing.confidencePercent,
                                templateFitConfidence: routing.templateFitConfidence,
                                routingCached: Boolean(routing.routingCached),
                            },
                            merged: {
                                assets: merged.assets,
                                scripts: merged.scripts,
                            },
                            appendScripts: refined.appendScripts,
                            addAssets: refined.addAssets,
                            removeScriptNames: refined.removeScriptNames,
                        });
                    }
                }
            }

            const refined = await refineHybridGame(
                openai,
                {
                    prompt: prompt.slice(0, MAX_PROMPT),
                    instruction: inst,
                    templates,
                    features,
                    scriptNames,
                    generationMode,
                },
                stripCodeFences,
                safeJsonParse
            );

            return res.json({
                success: true,
                path: "ai_refine",
                appendScripts: refined.appendScripts,
                addAssets: refined.addAssets,
                removeScriptNames: refined.removeScriptNames,
                message: refined.message,
            });
        } catch (e) {
            console.error("[refine-game]", e);
            return res.status(500).json({
                success: false,
                error: e instanceof Error ? e.message : "internal error",
            });
        }
    });
};
