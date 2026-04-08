/**
 * Single default OpenAI model for all routes (chat, planner, tiers, hybrid helpers).
 * Set OPENAI_MODEL in .env to override (optional legacy: OPENAI_CHAT_MODEL).
 */
const DEFAULT =
    String(process.env.OPENAI_MODEL || process.env.OPENAI_CHAT_MODEL || "").trim() || "gpt-5.3-latest";

module.exports = {
    CHAT: DEFAULT,
    PLANNER: DEFAULT,
    FAST_CHAT: DEFAULT,
    BALANCED_CHAT: DEFAULT,
    SMART_CHAT: DEFAULT,
    FAST_PLANNER: DEFAULT,
    BALANCED_PLANNER: DEFAULT,
    SMART_PLANNER: DEFAULT,
};
