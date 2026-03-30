/**
 * Shared OpenAI chat model IDs for server.js, hybrid routes, and asset keyword flow.
 * Set OPENAI_CHAT_MODEL / OPENAI_PLANNER_MODEL in .env to override defaults.
 */
module.exports = {
    CHAT: process.env.OPENAI_CHAT_MODEL || "gpt-5.3-chat-latest",
    PLANNER: process.env.OPENAI_PLANNER_MODEL || "gpt-5.4",
};
