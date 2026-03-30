const { analyzePromptForTemplates } = require("./promptAnalyzer");
const { normalizeTemplateOrder, listTemplateIds } = require("./templateLibrary");

const CACHE_MAX = parseInt(process.env.HYBRID_ROUTING_CACHE_MAX || "200", 10) || 200;

/** @type {Map<string, object>} */
const routingCache = new Map();

function routingCacheKey(prompt) {
    return String(prompt || "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ")
        .slice(0, 2000);
}

/**
 * @param {number|undefined} rawFit
 * @param {number|undefined} rawLegacy
 * @param {number} templatesLen
 */
function normalizeConfidenceValue(rawFit, rawLegacy, templatesLen) {
    if (typeof rawFit === "number" && !Number.isNaN(rawFit)) {
        return rawFit > 1 ? Math.min(1, rawFit / 100) : Math.max(0, Math.min(1, rawFit));
    }
    if (typeof rawLegacy === "number" && !Number.isNaN(rawLegacy)) {
        return rawLegacy > 1 ? Math.min(1, rawLegacy / 100) : Math.max(0, Math.min(1, rawLegacy));
    }
    return templatesLen >= 1 ? 0.78 : 0.32;
}

function getThreshold() {
    const t = parseFloat(process.env.HYBRID_TEMPLATE_CONFIDENCE_THRESHOLD || "0.7");
    if (Number.isNaN(t)) return 0.7;
    return Math.max(0, Math.min(1, t));
}

/** Lower bound for partial template alignment (inclusive). Below this → ai-only. */
function getPartialThreshold() {
    const t = parseFloat(process.env.HYBRID_TEMPLATE_PARTIAL_THRESHOLD || "0.45");
    if (Number.isNaN(t)) return 0.45;
    return Math.max(0, Math.min(1, t));
}

/**
 * @param {number} templatesLen
 * @param {number} conf
 * @returns {"full"|"partial"|"none"}
 */
function computeMatchTier(templatesLen, conf) {
    const fullT = getThreshold();
    let partialT = getPartialThreshold();
    if (partialT >= fullT) {
        partialT = Math.max(0, fullT - 0.05);
    }
    if (templatesLen === 0) return "none";
    if (conf >= fullT) return "full";
    if (conf >= partialT) return "partial";
    return "none";
}

/**
 * @param {"full"|"partial"|"none"} tier
 * @returns {"template"|"template+ai"|"ai-only"}
 */
function matchTierToMode(tier) {
    if (tier === "full") return "template";
    if (tier === "partial") return "template+ai";
    return "ai-only";
}

/**
 * @param {string} rawReason from model (may be empty)
 * @param {"full"|"partial"|"none"} matchTier
 * @param {string[]} templatesOut after tier filter
 * @param {number} conf
 * @param {boolean} hadTemplatesBeforeClear norm.templates.length > 0 before clearing for "none"
 */
function finalizeReason(rawReason, matchTier, templatesOut, conf, hadTemplatesBeforeClear) {
    const clipped = String(rawReason || "")
        .trim()
        .slice(0, 280);
    if (clipped) return clipped;

    const fullT = getThreshold();
    let partialT = getPartialThreshold();
    if (partialT >= fullT) partialT = Math.max(0, fullT - 0.05);
    const pct = Math.round(conf * 100);
    const pLow = Math.round(partialT * 100);
    const pFull = Math.round(fullT * 100);

    if (matchTier === "none") {
        if (hadTemplatesBeforeClear) {
            return `Template fit (${pct}%) fell below the partial threshold (${pLow}%); templates were not applied — AI-only generation.`;
        }
        return "No template ids matched above the confidence floor — AI-only generation.";
    }
    if (matchTier === "full") {
        const ids = Array.isArray(templatesOut) && templatesOut.length ? templatesOut.join(", ") : "templates";
        return `Confidence ${pct}% meets the full threshold (${pFull}%) for ${ids}.`;
    }
    return `Confidence ${pct}% is in the partial band (${pLow}%–${pFull}%) — template pack plus required AI hybrid layer.`;
}

/**
 * @param {import("openai").default} openai
 * @param {string} prompt
 * @param {(s: string) => string} stripCodeFences
 * @param {(s: string) => { ok: boolean, value?: any }} safeJsonParse
 */
async function computeTemplateRouting(openai, prompt, stripCodeFences, safeJsonParse) {
    const known = listTemplateIds();
    const raw = await analyzePromptForTemplates(openai, prompt, known, stripCodeFences, safeJsonParse);
    const norm = normalizeTemplateOrder(raw.templates, raw.features);
    const conf = normalizeConfidenceValue(raw.templateFitConfidence, raw.confidence, norm.templates.length);
    const hadTemplatesBeforeClear = norm.templates.length > 0;
    const matchTier = computeMatchTier(norm.templates.length, conf);
    const templatesOut = matchTier === "none" ? [] : norm.templates;
    const reason = finalizeReason(raw.reason || "", matchTier, templatesOut, conf, hadTemplatesBeforeClear);
    return {
        mode: matchTierToMode(matchTier),
        matchTier,
        reason,
        templateFitConfidence: conf,
        confidencePercent: Math.round(conf * 100),
        templates: templatesOut,
        features: norm.features,
    };
}

/**
 * Cached template detection only (no merge / no ai-only asset build).
 */
function ensureMatchTier(routing) {
    if (routing.matchTier) return routing;
    const m = routing.mode;
    const tier =
        m === "ai-only" ? "none" : m === "template+ai" ? "partial" : m === "template" ? "full" : "none";
    return { ...routing, matchTier: tier };
}

function ensureReason(routing) {
    if (routing.reason && String(routing.reason).trim()) return routing;
    const tier = routing.matchTier || "none";
    const templates = routing.templates || [];
    let conf = 0;
    if (typeof routing.templateFitConfidence === "number" && !Number.isNaN(routing.templateFitConfidence)) {
        conf = routing.templateFitConfidence;
    } else if (typeof routing.confidencePercent === "number" && !Number.isNaN(routing.confidencePercent)) {
        conf = Math.max(0, Math.min(1, routing.confidencePercent / 100));
    }
    const had = Array.isArray(templates) && templates.length > 0;
    const reason = finalizeReason("", tier, templates, conf, tier === "none" && had);
    return { ...routing, reason };
}

async function getOrCachedRouting(openai, prompt, stripCodeFences, safeJsonParse) {
    const key = routingCacheKey(prompt);
    const hit = routingCache.get(key);
    if (hit) {
        return { ...ensureReason(ensureMatchTier(hit)), routingCached: true };
    }
    const routing = await computeTemplateRouting(openai, prompt, stripCodeFences, safeJsonParse);
    routingCache.set(key, routing);
    while (routingCache.size > CACHE_MAX) {
        const first = routingCache.keys().next().value;
        routingCache.delete(first);
    }
    return { ...routing, routingCached: false };
}

module.exports = {
    getOrCachedRouting,
    computeTemplateRouting,
    routingCacheKey,
    normalizeConfidenceValue,
    getThreshold,
    getPartialThreshold,
    computeMatchTier,
    matchTierToMode,
    ensureMatchTier,
    ensureReason,
    finalizeReason,
};
