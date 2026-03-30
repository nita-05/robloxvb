const { loadLibrary, expandTemplate, listTemplateIds } = require("./templateLibrary");

/**
 * @typedef {{ type: string, detail?: object, message: string }} MergeValidationItem
 */

/**
 * Known template ids exist and optional incompatible pairs from gameTemplates.json _compatibility.
 * @param {string[]} orderedKeys
 * @returns {{ ok: boolean, items: MergeValidationItem[] }}
 */
function validateCompatibility(orderedKeys) {
    const items = [];
    const known = new Set(listTemplateIds());
    const keys = Array.isArray(orderedKeys) ? orderedKeys : [];

    for (const k of keys) {
        if (!known.has(k)) {
            items.push({
                type: "UNKNOWN_TEMPLATE",
                detail: { templateId: k },
                message: `Unknown template id "${k}" (not in game library).`,
            });
        }
    }

    const lib = loadLibrary();
    const compat = lib._compatibility && typeof lib._compatibility === "object" ? lib._compatibility : {};
    const pairs = Array.isArray(compat.incompatiblePairs) ? compat.incompatiblePairs : [];
    const active = new Set(keys);

    for (const pair of pairs) {
        if (!Array.isArray(pair) || pair.length < 2) continue;
        const a = String(pair[0] || "")
            .toLowerCase()
            .trim();
        const b = String(pair[1] || "")
            .toLowerCase()
            .trim();
        if (active.has(a) && active.has(b)) {
            items.push({
                type: "INCOMPATIBLE_PAIR",
                detail: { templates: [a, b] },
                message: `Library marks "${a}" and "${b}" as incompatible when merged together.`,
            });
        }
    }

    return { ok: items.length === 0, items };
}

/**
 * Same script name in different templates with different parent/className (merge keeps last by name).
 * @param {string[]} orderedKeys
 * @returns {{ items: MergeValidationItem[] }}
 */
function checkScriptSlotConflicts(orderedKeys) {
    const items = [];
    /** @type {Map<string, { parent: string, className: string, templateId: string }>} */
    const byName = new Map();
    const keys = Array.isArray(orderedKeys) ? orderedKeys : [];

    for (const key of keys) {
        const { scripts } = expandTemplate(key);
        for (const s of scripts) {
            const name = s.name;
            const prev = byName.get(name);
            if (prev) {
                if (prev.parent !== s.parent || prev.className !== s.className) {
                    items.push({
                        type: "SCRIPT_SLOT_CONFLICT",
                        detail: {
                            scriptName: name,
                            first: { templateId: prev.templateId, parent: prev.parent, className: prev.className },
                            second: { templateId: key, parent: s.parent, className: s.className },
                            resolution: "later_template_wins",
                        },
                        message: `Script "${name}" is defined with different parent/class in "${prev.templateId}" vs "${key}"; merge uses the later template's definition.`,
                    });
                }
            } else {
                byName.set(name, {
                    parent: s.parent,
                    className: s.className,
                    templateId: key,
                });
            }
        }
    }

    return { items };
}

/**
 * Duplicate WaitForChild / FindFirstChild string keys across scripts (possible shared-instance clash).
 * @param {{ name: string, source?: string }[]} scripts
 * @returns {{ items: MergeValidationItem[] }}
 */
const IGNORE_CHILD_KEYS = new Set([
    "Workspace",
    "ReplicatedStorage",
    "ServerScriptService",
    "ServerStorage",
    "StarterPlayer",
    "StarterGui",
    "StarterPack",
    "Players",
    "Lighting",
    "SoundService",
    "UserInputService",
    "RunService",
    "TweenService",
    "CollectionService",
    "HttpService",
    "MarketplaceService",
]);

function checkLuaEnvironmentHints(scripts) {
    const items = [];
    const reWait = /WaitForChild\s*\(\s*["']([^"']+)["']/g;
    const reFind = /FindFirstChild\s*\(\s*["']([^"']+)["']/g;
    /** @type {Map<string, string[]>} */
    const keyToScripts = new Map();

    for (const s of scripts || []) {
        const src = typeof s.source === "string" ? s.source : "";
        const n = typeof s.name === "string" ? s.name : "?";
        if (!src) continue;

        for (const re of [reWait, reFind]) {
            let m;
            const r = new RegExp(re.source, re.flags);
            while ((m = r.exec(src)) !== null) {
                const k = m[1];
                if (!k || k.length > 120) continue;
                if (IGNORE_CHILD_KEYS.has(k)) continue;
                const list = keyToScripts.get(k) || [];
                if (!list.includes(n)) list.push(n);
                keyToScripts.set(k, list);
            }
        }
    }

    for (const [childKey, scriptNames] of keyToScripts) {
        if (scriptNames.length > 1) {
            items.push({
                type: "POSSIBLE_INSTANCE_KEY_OVERLAP",
                detail: { childKey, scriptNames },
                message: `Multiple scripts wait/find "${childKey}" (${scriptNames.join(", ")}); ensure shared instances are intentional.`,
            });
        }
    }

    return { items };
}

/**
 * Hybrid-related Node env sanity (thresholds, flags).
 */
function validateNodeEnvironment() {
    const notes = [];
    const full = parseFloat(process.env.HYBRID_TEMPLATE_CONFIDENCE_THRESHOLD || "0.7");
    const partial = parseFloat(process.env.HYBRID_TEMPLATE_PARTIAL_THRESHOLD || "0.45");
    if (!Number.isNaN(full) && !Number.isNaN(partial) && partial >= full) {
        notes.push({
            type: "THRESHOLD_ORDER",
            message:
                "HYBRID_TEMPLATE_PARTIAL_THRESHOLD should be below HYBRID_TEMPLATE_CONFIDENCE_THRESHOLD (partial band must sit under full).",
        });
    }

    const aiLayer = String(process.env.HYBRID_AI_LAYER || "")
        .trim()
        .toLowerCase();
    if (aiLayer === "1" && String(process.env.HYBRID_PIPELINE_SKIP_REFINE || "").trim() === "1") {
        notes.push({
            type: "ENV_COMBINATION",
            message: "HYBRID_AI_LAYER=1 and HYBRID_PIPELINE_SKIP_REFINE=1 both set; pipeline still skips refine — confirm intentional.",
        });
    }

    return { ok: notes.length === 0, notes };
}

/**
 * Full pre-merge report for an ordered template list and optional merged script list (templates + AI scripts).
 * @param {string[]} orderedKeys
 * @param {{ name: string, source?: string }[]} [mergedScriptsForEnvScan]
 */
function buildPreMergeReport(orderedKeys, mergedScriptsForEnvScan) {
    const compat = validateCompatibility(orderedKeys);
    const slot = checkScriptSlotConflicts(orderedKeys);
    const node = validateNodeEnvironment();

    const envLua = mergedScriptsForEnvScan && mergedScriptsForEnvScan.length
        ? checkLuaEnvironmentHints(mergedScriptsForEnvScan)
        : { items: [] };

    const blocking = [...compat.items];

    return {
        compatible: compat.ok && blocking.length === 0,
        scriptConflicts: slot.items,
        luaEnvironmentHints: envLua.items,
        nodeEnvironment: node,
        blockingIssues: blocking,
        okToMerge: blocking.length === 0,
    };
}

module.exports = {
    validateCompatibility,
    checkScriptSlotConflicts,
    checkLuaEnvironmentHints,
    validateNodeEnvironment,
    buildPreMergeReport,
};
