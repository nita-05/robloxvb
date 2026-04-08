const { getPool } = require("../db/pool");

async function cleanupOldJobs() {
    const pool = getPool();
    if (!pool) return { ok: false, skipped: true, reason: "DATABASE_URL not set" };

    const hours = Number(process.env.JOB_RETENTION_HOURS || 24);
    const keepHours = Number.isFinite(hours) && hours > 0 ? hours : 24;

    const r = await pool.query(
        `delete from jobs where created_at < (now() - ($1::text || ' hours')::interval)`,
        [String(keepHours)]
    );
    return { ok: true, deletedJobs: r.rowCount || 0, keepHours };
}

module.exports = { cleanupOldJobs };

