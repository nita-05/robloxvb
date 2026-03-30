const { getOrCachedRouting, computeTemplateRouting } = require("./hybridRouting");
const { mergeTemplates } = require("./templateLibrary");
const { buildAiOnlyMerged } = require("./hybridAiOnlyFallback");
const { generateHybridEnhancement } = require("./hybridEnhance");
const { refineHybridGame } = require("./hybridRefine");
const { buildPreMergeReport } = require("./templateMergeValidation");

const MAX_P = 2000;
const MAX_INST = 1200;

const DEFAULT_REFINE =
    process.env.HYBRID_PIPELINE_REFINE_INSTRUCTION ||
    "Polish pass: align scripts with workspace.GeneratedGame; remove dead code; add brief comments. Only add HybridExt_* glue if something critical is missing.";

const SECOND_REFINE =
    process.env.HYBRID_PIPELINE_SECOND_REFINE_INSTRUCTION ||
    "Second pass after classifier recheck: align GeneratedGame with routing; only HybridExt_* glue if needed; keep changes minimal.";

/**
 * Max refine→recheck rounds (each round = 1 refine + 1 re-classification). Capped at 2 to avoid runaway cost.
 * Default 1 (single refine + single recheck). Set to 2 to allow one extra round only when the first recheck suggests a smart-loop mismatch.
 */
function getMaxRecheckCycles() {
    const n = parseInt(process.env.HYBRID_PIPELINE_MAX_RECHECK_CYCLES || "1", 10);
    if (Number.isNaN(n)) return 1;
    return Math.min(2, Math.max(1, n));
}

/**
 * @param {object} routing
 * @param {object} recheckRouting
 * @returns {string|null}
 */
function computeSmartLoopHint(routing, recheckRouting) {
    if (!recheckRouting) return null;
    const recheckTemplateLike =
        recheckRouting.mode === "template" || recheckRouting.mode === "template+ai";
    const startTemplateLike = routing.mode === "template" || routing.mode === "template+ai";
    if (routing.mode === "ai-only" && recheckTemplateLike) {
        return "recheck_suggests_templates";
    }
    if (startTemplateLike && recheckRouting.mode === "ai-only") {
        return "recheck_suggests_ai_only";
    }
    return null;
}

/**
 * Full chain: template detection → generate (template + optional AI enhance, or ai-only) →
 * bounded refine + re-classification cycles (max 1–2 by env).
 *
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {{ wantEnhance?: boolean, alwaysRefine?: boolean, refineInstruction?: string, skipCache?: boolean, forceAiOnly?: boolean }} opts
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function runGenerationPipeline(openai, prompt, opts, stripCodeFences, safeJsonParse) {
    const wantEnhance =
        opts.wantEnhance === true ||
        String(process.env.HYBRID_AI_LAYER || "")
            .trim()
            .toLowerCase() === "1";

    const forceAiOnly = opts.forceAiOnly === true;

    const skipByEnv = String(process.env.HYBRID_PIPELINE_SKIP_REFINE || "")
        .trim()
        .toLowerCase() === "1";
    const alwaysRefine = opts.alwaysRefine !== false && !skipByEnv;

    const skipRoutingCache = opts.skipCache === true;
    const refineInstruction = (opts.refineInstruction && String(opts.refineInstruction).trim()) || DEFAULT_REFINE;

    const maxRecheckCycles = getMaxRecheckCycles();

    const routing = skipRoutingCache
        ? { ...(await computeTemplateRouting(openai, prompt, stripCodeFences, safeJsonParse)), routingCached: false }
        : await getOrCachedRouting(openai, prompt, stripCodeFences, safeJsonParse);

    const forcedAiFallback = forceAiOnly && routing.mode !== "ai-only";

    /** @type {{ assets: number[], scripts: object[] }} */
    let merged;
    let genMessage = "";
    let assetKeywords = [];

    const tier = routing.matchTier || (routing.mode === "template+ai" ? "partial" : routing.mode === "ai-only" ? "none" : "full");

    if (routing.mode === "ai-only" || forcedAiFallback) {
        const ai = await buildAiOnlyMerged(openai, prompt, routing.features, stripCodeFences, safeJsonParse);
        merged = { assets: ai.assets, scripts: ai.scripts };
        genMessage = ai.message || "";
        assetKeywords = ai.assetKeywords || [];
    } else {
        const m = mergeTemplates(routing.templates);
        let extra = [];
        let enhanceMessage = "";
        const forceEnhance = tier === "partial";
        if (forceEnhance || wantEnhance) {
            const enh = await generateHybridEnhancement(
                openai,
                prompt,
                routing.features,
                {
                    templateIds: routing.templates,
                    scriptNames: m.scripts.map((s) => s.name),
                    assetCount: m.assets.length,
                },
                stripCodeFences,
                safeJsonParse
            );
            extra = enh.scripts || [];
            enhanceMessage = enh.message || "";
        }
        merged = { assets: m.assets, scripts: [...m.scripts, ...extra] };
        genMessage = enhanceMessage;
    }

    const aiEnhancementApplied = !forcedAiFallback && (tier === "partial" || wantEnhance);
    const aiEnhancementMeta = forcedAiFallback
        ? {
              optional: true,
              forced: false,
              requested: wantEnhance,
              applied: false,
              aiOnlyFallbackUsed: true,
              alwaysAvailable: true,
          }
        : routing.mode === "ai-only"
          ? {
                optional: false,
                forced: false,
                requested: false,
                applied: false,
                aiOnlyBuild: true,
                alwaysAvailable: true,
            }
          : {
                optional: tier === "full",
                forced: tier === "partial",
                requested: wantEnhance,
                applied: aiEnhancementApplied,
                alwaysAvailable: true,
            };

    /** @type {object|null} */
    let refinement = null;
    /** @type {object|null} */
    let recheckRouting = null;
    let recheckCyclesUsed = 0;
    /** @type {object[]} */
    const recheckHistory = [];
    /** @type {string[]} */
    const refineMessages = [];
    /** @type {string[]} */
    const accumulatedRemoveScriptNames = [];

    let assets = [...(merged.assets || [])];
    let scripts = [...(merged.scripts || [])];

    const refineTemplates = forcedAiFallback ? [] : routing.templates;
    const refineGenMode = routing.mode === "ai-only" || forcedAiFallback ? "ai-only" : "template";
    const routingForSmartLoop =
        forcedAiFallback
            ? { ...routing, mode: "ai-only", matchTier: "none", templates: [], reason: routing.reason }
            : routing;

    if (alwaysRefine) {
        for (let cycle = 0; cycle < maxRecheckCycles; cycle++) {
            const inst =
                cycle === 0 ? refineInstruction.slice(0, MAX_INST) : SECOND_REFINE.slice(0, MAX_INST);
            const scriptNames = scripts.map((s) => s.name);

            refinement = await refineHybridGame(
                openai,
                {
                    prompt: String(prompt).slice(0, MAX_P),
                    instruction: inst,
                    templates: refineTemplates,
                    features: routing.features,
                    scriptNames,
                    generationMode: refineGenMode,
                },
                stripCodeFences,
                safeJsonParse
            );

            if (refinement && Array.isArray(refinement.addAssets)) {
                for (const id of refinement.addAssets) {
                    const n = typeof id === "string" ? parseInt(id, 10) : Number(id);
                    if (Number.isFinite(n) && n > 0 && !assets.includes(n)) assets.push(n);
                }
            }
            if (refinement && Array.isArray(refinement.appendScripts)) {
                scripts.push(...refinement.appendScripts);
            }
            if (refinement && Array.isArray(refinement.removeScriptNames)) {
                for (const n of refinement.removeScriptNames) {
                    if (typeof n === "string" && n.startsWith("HybridExt_")) accumulatedRemoveScriptNames.push(n);
                }
            }
            if (refinement && typeof refinement.message === "string" && refinement.message.trim()) {
                refineMessages.push(refinement.message.trim());
            }

            const recap = `${String(prompt).slice(0, 1200)}\n\nRefinement summary: ${(refinement.message || "").slice(0, 600)}`.slice(
                0,
                MAX_P
            );
            recheckRouting = await computeTemplateRouting(openai, recap, stripCodeFences, safeJsonParse);
            recheckCyclesUsed += 1;
            recheckHistory.push({
                cycle: recheckCyclesUsed,
                matchTier: recheckRouting.matchTier,
                mode: recheckRouting.mode,
                reason: recheckRouting.reason,
            });

            if (cycle + 1 >= maxRecheckCycles) {
                break;
            }
            const hint = computeSmartLoopHint(routingForSmartLoop, recheckRouting);
            if (!hint) {
                break;
            }
        }

        if (refinement) {
            refinement = {
                ...refinement,
                message: refineMessages.length ? refineMessages.join(" | ") : refinement.message || "",
                removeScriptNames: [...new Set(accumulatedRemoveScriptNames)],
                appendScripts: [],
                addAssets: [],
            };
        }
    } else {
        recheckRouting = routing;
    }

    const templateKeysForReport =
        routing.mode === "ai-only" || forcedAiFallback ? [] : routing.templates;
    const preMerge = buildPreMergeReport(templateKeysForReport, scripts);

    let smartLoopHint = null;
    if (alwaysRefine && recheckRouting) {
        smartLoopHint = computeSmartLoopHint(routingForSmartLoop, recheckRouting);
    }

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
        : null;

    const appliedReason = forcedAiFallback
        ? "AI-only fallback was used for this build; see classifierRouting for what the classifier matched."
        : routing.reason;

    return {
        routing,
        forcedAiFallback,
        classifierRouting,
        appliedMode: forcedAiFallback ? "ai-only" : routing.mode,
        appliedMatchTier: forcedAiFallback ? "none" : routing.matchTier,
        appliedReason,
        aiEnhancement: aiEnhancementMeta,
        merged,
        mergedFinal: { assets, scripts },
        preMerge,
        refinement,
        recheckRouting,
        smartLoopHint,
        recheckCyclesUsed,
        recheckCycleLimit: maxRecheckCycles,
        recheckHistory,
        assetKeywords,
        pipeline: {
            alwaysRefine,
            wantEnhance,
            refineRan: alwaysRefine,
            forceAiOnly: Boolean(forceAiOnly),
        },
        message: genMessage,
    };
}

module.exports = { runGenerationPipeline, DEFAULT_REFINE, getMaxRecheckCycles, computeSmartLoopHint };
