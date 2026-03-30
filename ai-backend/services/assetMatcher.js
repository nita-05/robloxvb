const fs = require("fs");
const path = require("path");

let datasetCache = null;

function norm(s) {
    return String(s || "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim()
        .replace(/\s+/g, " ");
}

/**
 * @param {string} phrase
 * @param {string} datasetKey
 * @returns {number}
 */
function keywordScore(phrase, datasetKey) {
    const a = norm(phrase);
    const b = norm(datasetKey);
    if (!a || !b) return 0;
    if (a === b) return 100;
    if (a.includes(b) || b.includes(a)) return 70;

    const ta = a.split(" ").filter((t) => t.length > 0);
    const tb = b.split(" ").filter((t) => t.length > 0);
    let hits = 0;
    for (const t of ta) {
        for (const u of tb) {
            if (t === u) hits += 3;
            else if (t.length > 2 && u.length > 2 && (t.includes(u) || u.includes(t))) hits += 1;
        }
    }
    return hits * 8;
}

/**
 * @param {string[]} keywords
 * @param {Record<string, number[]|string[]>} dataset
 * @param {{ limit?: number, maxCap?: number }} opts
 * @returns {{ assets: number[], scores: Map<number, number> }}
 */
function matchAssetsFromKeywords(keywords, dataset, opts) {
    const limit = Math.min(Math.max(opts.limit ?? 10, 1), opts.maxCap ?? 15);
    const keys = Object.keys(dataset || {});
    /** @type {Map<number, number>} */
    const scores = new Map();

    const list = Array.isArray(keywords) ? keywords : [];
    for (const phrase of list) {
        if (typeof phrase !== "string") continue;
        const p = phrase.trim();
        if (!p) continue;

        for (const dk of keys) {
            const add = keywordScore(p, dk);
            if (add <= 0) continue;

            const row = dataset[dk];
            if (!Array.isArray(row)) continue;
            for (const raw of row) {
                const id = typeof raw === "string" ? parseInt(raw, 10) : Number(raw);
                if (!Number.isFinite(id) || id <= 0) continue;
                scores.set(id, (scores.get(id) || 0) + add);
            }
        }
    }

    const ranked = [...scores.entries()].sort((x, y) => y[1] - x[1]);
    const assets = [];
    for (const [id] of ranked) {
        assets.push(id);
        if (assets.length >= limit) break;
    }

    return { assets, scores };
}

function loadDataset() {
    if (datasetCache) return datasetCache;
    const fp = path.join(__dirname, "..", "data", "assets.json");
    const raw = fs.readFileSync(fp, "utf8");
    const data = JSON.parse(raw);
    if (!data || typeof data !== "object") {
        throw new Error("assets.json must be an object");
    }
    datasetCache = data;
    return datasetCache;
}

function reloadDataset() {
    datasetCache = null;
    return loadDataset();
}

module.exports = {
    matchAssetsFromKeywords,
    loadDataset,
    reloadDataset,
    norm,
};
