const crypto = require("crypto");
const { getPool } = require("../db/pool");

function uuid() {
    return crypto.randomUUID();
}

function nowIso() {
    return new Date().toISOString();
}

function normalizeUserId(req) {
    const h = String(req.get("x-user-id") || "").trim();
    const b = String(req.body?.userId || "").trim();
    const ip = String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "unknown").split(",")[0].trim();
    return h || b || ip || "unknown";
}

async function createJob({ userId, type, requestJson }) {
    const pool = getPool();
    if (!pool) throw new Error("DATABASE_URL not set");

    const id = uuid();
    await pool.query(
        `insert into jobs (id, user_id, type, status, request_json, created_at, updated_at)
         values ($1, $2, $3, 'queued', $4::jsonb, now(), now())`,
        [id, userId, type, JSON.stringify(requestJson)]
    );
    await appendEvent({ jobId: id, level: "info", message: `[${nowIso()}] queued` });
    return id;
}

async function appendEvent({ jobId, level = "info", message }) {
    const pool = getPool();
    if (!pool) return;
    await pool.query(`insert into job_events (job_id, level, message) values ($1, $2, $3)`, [jobId, level, message]);
}

async function setJobStatus({ jobId, status, resultJson = null, error = null }) {
    const pool = getPool();
    if (!pool) return;
    await pool.query(
        `update jobs set status=$2, result_json=$3::jsonb, error=$4, updated_at=now() where id=$1`,
        [jobId, status, resultJson ? JSON.stringify(resultJson) : null, error]
    );
}

async function getJob({ jobId }) {
    const pool = getPool();
    if (!pool) throw new Error("DATABASE_URL not set");
    const r = await pool.query(`select id, user_id, type, status, request_json, result_json, error, created_at, updated_at from jobs where id=$1`, [
        jobId,
    ]);
    return r.rows[0] || null;
}

async function getEventsSince({ jobId, afterId = 0, limit = 200 }) {
    const pool = getPool();
    if (!pool) throw new Error("DATABASE_URL not set");
    const r = await pool.query(
        `select id, ts, level, message from job_events where job_id=$1 and id > $2 order by id asc limit $3`,
        [jobId, afterId, limit]
    );
    return r.rows;
}

module.exports = {
    normalizeUserId,
    createJob,
    appendEvent,
    setJobStatus,
    getJob,
    getEventsSince,
};

