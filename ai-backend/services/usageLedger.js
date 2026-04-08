const { getPool } = require("../db/pool");

async function ensureUserExists(userId) {
    const pool = getPool();
    if (!pool) return;
    await pool.query(
        `insert into users (id) values ($1)
         on conflict (id) do nothing`,
        [userId]
    );
}

/**
 * @param {{ userId: string, jobId?: string|null, action: string, model?: string|null, tokensIn?: number|null, tokensOut?: number|null, costEstimateUsd?: number|null }} entry
 */
async function recordUsage(entry) {
    const pool = getPool();
    if (!pool) return;

    const userId = String(entry.userId || "").trim();
    if (!userId) return;
    await ensureUserExists(userId);

    await pool.query(
        `insert into usage_ledger (user_id, job_id, action, model, tokens_in, tokens_out, cost_estimate_usd)
         values ($1, $2, $3, $4, $5, $6, $7)`,
        [
            userId,
            entry.jobId || null,
            String(entry.action || "unknown"),
            entry.model || null,
            entry.tokensIn ?? null,
            entry.tokensOut ?? null,
            entry.costEstimateUsd ?? null,
        ]
    );
}

module.exports = { recordUsage };

