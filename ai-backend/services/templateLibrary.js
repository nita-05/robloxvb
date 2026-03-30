const fs = require("fs");
const path = require("path");

let libCache = null;
const LUA_DIR = path.join(__dirname, "..", "templates", "lua");

function loadLibrary() {
    if (libCache) return libCache;
    const raw = fs.readFileSync(path.join(__dirname, "..", "data", "gameTemplates.json"), "utf8");
    libCache = JSON.parse(raw);
    return libCache;
}

function listTemplateIds() {
    return Object.keys(loadLibrary()).filter((k) => !k.startsWith("_"));
}

/**
 * @param {{ name: string, parent: string, className: string, file?: string, source?: string }} ref
 * @returns {{ name: string, parent: string, className: string, source: string } | null}
 */
function resolveScriptRef(ref) {
    if (!ref || typeof ref.name !== "string") return null;
    const parent = ref.parent === "StarterPlayerScripts" ? "StarterPlayerScripts" : "ServerScriptService";
    const className = ref.className === "LocalScript" ? "LocalScript" : "Script";

    let source = typeof ref.source === "string" ? ref.source : "";
    if (!source && typeof ref.file === "string") {
        const fp = path.join(LUA_DIR, path.basename(ref.file));
        if (!fs.existsSync(fp)) {
            console.warn("[templateLibrary] missing file:", fp);
            return null;
        }
        source = fs.readFileSync(fp, "utf8");
    }
    if (!source) return null;

    return { name: ref.name, parent, className, source };
}

/**
 * Resolve one template's scriptRefs to full script objects.
 * @param {string} key
 * @returns {{ assets: number[], scripts: object[] }}
 */
function expandTemplate(key) {
    const lib = loadLibrary();
    const t = lib[key];
    if (!t || typeof t !== "object") {
        return { assets: [], scripts: [] };
    }
    const assets = [];
    if (Array.isArray(t.assets)) {
        for (const a of t.assets) {
            const id = typeof a === "string" ? parseInt(a, 10) : Number(a);
            if (Number.isFinite(id) && id > 0) assets.push(id);
        }
    }
    const scripts = [];
    const refs = Array.isArray(t.scriptRefs) ? t.scriptRefs : [];
    for (const ref of refs) {
        const s = resolveScriptRef(ref);
        if (s) scripts.push(s);
    }
    return { assets, scripts };
}

/**
 * Merge ordered templates: assets deduped in order; scripts by name — later template wins (enhancement).
 * @param {string[]} orderedKeys
 */
function mergeTemplates(orderedKeys) {
    const seenAssets = new Set();
    const mergedAssets = [];
    /** @type {Map<string, object>} */
    const scriptByName = new Map();

    const keys = Array.isArray(orderedKeys) ? orderedKeys : [];
    for (const key of keys) {
        const { assets, scripts } = expandTemplate(key);
        for (const id of assets) {
            if (!seenAssets.has(id)) {
                seenAssets.add(id);
                mergedAssets.push(id);
            }
        }
        for (const s of scripts) {
            scriptByName.set(s.name, s);
        }
    }

    return {
        assets: mergedAssets,
        scripts: [...scriptByName.values()],
    };
}

function normalizeTemplateOrder(templates, features) {
    const known = new Set(listTemplateIds());
    const out = [];
    for (const t of templates || []) {
        const k = String(t || "")
            .toLowerCase()
            .trim();
        if (known.has(k) && !out.includes(k)) out.push(k);
    }
    return { templates: out, features: Array.isArray(features) ? features.map((x) => String(x)) : [] };
}

module.exports = {
    loadLibrary,
    listTemplateIds,
    mergeTemplates,
    expandTemplate,
    resolveScriptRef,
    normalizeTemplateOrder,
};
