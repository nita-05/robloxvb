/**
 * Shared OpenAI chat model IDs for server.js, hybrid routes, and asset keyword flow.
 * Set OPENAI_CHAT_MODEL / OPENAI_PLANNER_MODEL in .env to override defaults.
 */
module.exports = {
    CHAT: process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",
    PLANNER: process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",

    // Model tiers (defaults match VibeCoder tier labels)
    // You can override any tier via env vars below.
    FAST_CHAT: process.env.OPENAI_FAST_CHAT_MODEL || "gpt-5-mini",
    BALANCED_CHAT: process.env.OPENAI_BALANCED_CHAT_MODEL || "gpt-5.2",
    SMART_CHAT: process.env.OPENAI_SMART_CHAT_MODEL || "gpt-5.3",

    FAST_PLANNER: process.env.OPENAI_FAST_PLANNER_MODEL || "gpt-5-mini",
    BALANCED_PLANNER: process.env.OPENAI_BALANCED_PLANNER_MODEL || "gpt-5.2",
    SMART_PLANNER: process.env.OPENAI_SMART_PLANNER_MODEL || "gpt-5.4",
};
