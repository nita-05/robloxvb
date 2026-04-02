/**
 * Shared OpenAI chat model IDs for server.js, hybrid routes, and asset keyword flow.
 * Set OPENAI_CHAT_MODEL / OPENAI_PLANNER_MODEL in .env to override defaults.
 */
module.exports = {
    CHAT: process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",
    PLANNER: process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",

    // Model tiers (defaults to CHAT/PLANNER for backward compatibility)
    FAST_CHAT: process.env.OPENAI_FAST_CHAT_MODEL || process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",
    BALANCED_CHAT: process.env.OPENAI_BALANCED_CHAT_MODEL || process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",
    SMART_CHAT: process.env.OPENAI_SMART_CHAT_MODEL || process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",

    FAST_PLANNER: process.env.OPENAI_FAST_PLANNER_MODEL || process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",
    BALANCED_PLANNER: process.env.OPENAI_BALANCED_PLANNER_MODEL || process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",
    SMART_PLANNER: process.env.OPENAI_SMART_PLANNER_MODEL || process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",
};
