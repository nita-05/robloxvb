const { Pool } = require("pg");

const DATABASE_URL = String(process.env.DATABASE_URL || "").trim();

/** @type {import("pg").Pool | null} */
let pool = null;

function getPool() {
    if (!DATABASE_URL) return null;
    if (pool) return pool;

    pool = new Pool({
        connectionString: DATABASE_URL,
        // Render/most managed PG require SSL. Local PG often doesn't.
        ssl:
            String(process.env.PGSSL || "").trim() === "0"
                ? false
                : { rejectUnauthorized: false },
        max: Number(process.env.PG_POOL_MAX || 10),
    });
    return pool;
}

module.exports = { getPool };

