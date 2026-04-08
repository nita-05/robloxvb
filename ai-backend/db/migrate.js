const { getPool } = require("./pool");

async function migrate() {
    const pool = getPool();
    if (!pool) {
        return { ok: false, skipped: true, reason: "DATABASE_URL not set" };
    }

    // Minimal users table (for billing/entitlements later).
    await pool.query(`
        create table if not exists users (
            id text primary key,
            plan text not null default 'free',
            status text not null default 'active',
            current_period_end timestamptz,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
        );
    `);

    // Jobs table: stores request, status, and result.
    await pool.query(`
        create table if not exists jobs (
            id uuid primary key,
            user_id text not null,
            type text not null,
            status text not null,
            request_json jsonb not null,
            result_json jsonb,
            error text,
            created_at timestamptz not null default now(),
            updated_at timestamptz not null default now()
        );
    `);

    await pool.query(`create index if not exists jobs_user_id_created_at_idx on jobs (user_id, created_at desc);`);
    await pool.query(`create index if not exists jobs_status_idx on jobs (status);`);

    // Job events table: append-only progress messages.
    await pool.query(`
        create table if not exists job_events (
            id bigserial primary key,
            job_id uuid not null references jobs(id) on delete cascade,
            ts timestamptz not null default now(),
            level text not null default 'info',
            message text not null
        );
    `);
    await pool.query(`create index if not exists job_events_job_id_id_idx on job_events (job_id, id);`);

    // Usage ledger: keep forever (billing/limits source of truth).
    await pool.query(`
        create table if not exists usage_ledger (
            id bigserial primary key,
            user_id text not null,
            job_id uuid,
            action text not null,
            model text,
            tokens_in int,
            tokens_out int,
            cost_estimate_usd numeric,
            created_at timestamptz not null default now()
        );
    `);
    await pool.query(`create index if not exists usage_ledger_user_id_created_at_idx on usage_ledger (user_id, created_at desc);`);

    return { ok: true, skipped: false };
}

module.exports = { migrate };

