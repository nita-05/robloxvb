require("dotenv").config();
const express = require("express");
const cors = require("cors");
const OpenAI = require("openai");

const app = express();
app.use(cors());
app.use(express.json());

const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
});

app.get("/", (req, res) => {
    res.status(200).send("OK");
});

app.get("/health", (req, res) => {
    res.status(200).json({ ok: true });
});

function safeJsonParse(text) {
    try {
        return { ok: true, value: JSON.parse(text) };
    } catch (e) {
        return { ok: false, error: e };
    }
}

function validateStructuredBuild(build) {
    // Minimal validation (kept intentionally permissive, but safe)
    if (!build || typeof build !== "object") return { ok: false, error: "build must be an object" };
    if (!Array.isArray(build.instances)) return { ok: false, error: "build.instances must be an array" };

    for (const inst of build.instances) {
        if (!inst || typeof inst !== "object") return { ok: false, error: "instance must be an object" };
        if (typeof inst.id !== "string" || !inst.id) return { ok: false, error: "instance.id required" };
        if (typeof inst.className !== "string" || !inst.className) return { ok: false, error: "instance.className required" };
        if (inst.parent && typeof inst.parent !== "string") return { ok: false, error: "instance.parent must be string id" };
        if (inst.properties && typeof inst.properties !== "object") return { ok: false, error: "instance.properties must be object" };
        if (inst.source != null && typeof inst.source !== "string") return { ok: false, error: "instance.source must be string" };
    }

    return { ok: true };
}

function stripCodeFences(text) {
    if (!text) return "";
    const s = String(text);

    // Prefer extracting the first fenced code block if present (models often add prose).
    const fenceMatch = s.match(/```[a-zA-Z]*\s*\n([\s\S]*?)\n?```/m);
    if (fenceMatch && fenceMatch[1]) return fenceMatch[1].trim();

    // Otherwise, fall back to trimming a single leading/trailing fence.
    return s
        .replace(/^```[a-zA-Z]*\s*\n?/m, "")
        .replace(/\n?```$/m, "")
        .trim();
}

function quickPlanFromPrompt(prompt) {
    const p = String(prompt || "").toLowerCase();
    const steps = [
        "1. Set up a clean spawn/start area and base layout.",
        "2. Build core gameplay objects and progression path.",
        "3. Add checkpoints, fail/reset zones, and win condition.",
        "4. Add basic UI feedback and polish lighting/sounds.",
        "5. Test in Studio and adjust difficulty/positions."
    ];

    const isObby = p.includes("obby") || p.includes("parkour") || p.includes("obstacle");
    const isHorror = p.includes("horror") || p.includes("scary") || p.includes("ghost") || p.includes("dark") || p.includes("creepy");
    const isRacing = p.includes("racing") || p.includes("race") || p.includes("car") || p.includes("drive");
    const isShooter = p.includes("shooter") || p.includes("gun") || p.includes("fps") || p.includes("weapon");
    const isCoinCollector = (p.includes("coin") || p.includes("coins") || p.includes("collector")) && (p.includes("score") || p.includes("collect") || p.includes("touch") || p.includes("obby") === false);

    if (isCoinCollector) {
        steps[0] = "1. Create spawn area + workspace coin folder.";
        steps[1] = "2. Create 20-50 spinning coin parts (gold/Neon/Metal) with CanCollide=false.";
        steps[2] = "3. Add ServerScript: leaderstats `Score` and coin.Touched debounce; +5 per coin; Destroy coin.";
        steps[3] = "4. Add ScreenGui + LocalScript top-left score label synced to leaderstats.";
        steps[4] = "5. When all coins collected, show win UI and optionally stop/refresh coins.";
    } else if (isObby) {
        steps[1] = "2. Build sequential platforms/obstacles from start to finish.";
        steps[2] = "3. Add checkpoints and kill/reset zones between sections.";
        if (isHorror) {
            steps[0] = "1. Build a horror lobby + clear instructions; add SpawnLocation on stage 1.";
            steps[3] = "4. Add moody lighting/fog + safe flicker/jumpscare moments (no audio assets).";
            steps[4] = "5. Playtest spawn height + checkpoint detection; ensure landing is fair.";
        }
    } else if (isRacing) {
        steps[1] = "2. Build track path, start line, and checkpoint sequence.";
        steps[2] = "3. Add lap/timer logic and race completion condition.";
    } else if (isShooter) {
        steps[1] = "2. Add weapon/tool flow and target or enemy interactions.";
        steps[2] = "3. Add hit handling, cooldown/ammo, and round objective.";
        if (isHorror) {
            steps[0] = "1. Build a dark arena with safe lighting + simple wave spawns.";
            steps[3] = "4. Add HUD + small scary visuals (fog/shadows) without relying on sounds.";
        }
    }

    return steps.join("\n");
}


// 🧠 INTENT DETECTOR
function detectIntent(prompt) {
    const p = prompt.toLowerCase();

    if (p.includes("create") || p.includes("build")) return "build";
    if (p.includes("add rain") || p.includes("rain")) return "wow";
    if (p.includes("fun") || p.includes("improve")) return "conversation";

    return "build";
}


// 🧩 TEMPLATE DETECTOR
function detectGameType(prompt) {
    const p = prompt.toLowerCase();

    // 🎯 keyword groups
    const types = {
        obby: ["obby", "parkour", "jump", "obstacle"],
        tycoon: ["tycoon", "factory", "business", "income"],
        horror: ["horror", "scary", "ghost", "dark", "creepy"],
        simulator: ["simulator", "clicker", "farm", "collect"],
        shooter: ["shooter", "gun", "fps", "battle", "weapon"],
        racing: ["race", "racing", "car", "drive"]
    };

    for (const type in types) {
        for (const keyword of types[type]) {
            if (p.includes(keyword)) {
                return type;
            }
        }
    }

    return "default";
}

function detectGameTypes(prompt) {
    const p = prompt.toLowerCase();

    const types = {
        obby: ["obby", "parkour", "obstacle"],
        tycoon: ["tycoon", "business"],
        horror: ["horror", "scary", "ghost"],
        simulator: ["simulator", "click"],
        shooter: ["shooter", "gun", "fps"],
        racing: ["race", "car"]
    };

    let matched = [];

    for (const type in types) {
        for (const keyword of types[type]) {
            if (p.includes(keyword)) {
                matched.push(type);
                break;
            }
        }
    }

    return matched.length > 0 ? matched : ["default"];
}


// 🚗 TEMPLATE EXAMPLE
function racingTemplate() {
    return `
local part = Instance.new("Part")
part.Size = Vector3.new(200,1,20)
part.Anchored = true
part.Parent = workspace
`;
}

function obbyTemplate() {
return `
-- 🧗 Obby Platforms
for i = 1,10 do
    local part = Instance.new("Part")
    part.Size = Vector3.new(10,1,10)
    part.Position = Vector3.new(i*12, i*4, 0)
    part.Anchored = true
    part.BrickColor = BrickColor.Random()
    part.Parent = workspace
end

-- 🔁 Kill Part
local kill = Instance.new("Part")
kill.Size = Vector3.new(50,1,50)
kill.Position = Vector3.new(60,0,0)
kill.BrickColor = BrickColor.new("Bright red")
kill.Anchored = true
kill.Parent = workspace

kill.Touched:Connect(function(hit)
    local hum = hit.Parent:FindFirstChild("Humanoid")
    if hum then hum.Health = 0 end
end)
`;
}

function tycoonTemplate() {
return `
-- 🏢 Money System
local player = game.Players.LocalPlayer

local stats = Instance.new("Folder", player)
stats.Name = "leaderstats"

local cash = Instance.new("IntValue", stats)
cash.Name = "Cash"
cash.Value = 0

-- 💰 Dropper
while true do
    local drop = Instance.new("Part")
    drop.Size = Vector3.new(2,2,2)
    drop.Position = Vector3.new(0,10,0)
    drop.BrickColor = BrickColor.new("Bright green")
    drop.Parent = workspace

    drop.Touched:Connect(function(hit)
        if hit.Parent == player.Character then
            cash.Value += 10
            drop:Destroy()
        end
    end)

    wait(2)
end
`;
}

function horrorTemplate() {
return `
-- 👻 Dark Lighting
local lighting = game:GetService("Lighting")
lighting.ClockTime = 0
lighting.Brightness = 1
lighting.FogEnd = 50

-- 👻 Ghost
local ghost = Instance.new("Part")
ghost.Size = Vector3.new(4,6,2)
ghost.Position = Vector3.new(0,5,20)
ghost.BrickColor = BrickColor.new("Institutional white")
ghost.Parent = workspace

-- 👻 Move Ghost
game:GetService("RunService").Heartbeat:Connect(function()
    ghost.Position = ghost.Position + Vector3.new(math.random(-1,1),0,math.random(-1,1))
end)
`;
}

function simulatorTemplate() {
return `
-- 🪙 Click Simulator
local player = game.Players.LocalPlayer

local stats = Instance.new("Folder", player)
stats.Name = "leaderstats"

local coins = Instance.new("IntValue", stats)
coins.Name = "Coins"
coins.Value = 0

local part = Instance.new("Part")
part.Size = Vector3.new(5,1,5)
part.Position = Vector3.new(0,3,0)
part.Anchored = true
part.Parent = workspace

part.Touched:Connect(function(hit)
    if hit.Parent == player.Character then
        coins.Value += 1
    end
end)
`;
}

function shooterTemplate() {
return `
-- 🔫 Basic Gun
local tool = Instance.new("Tool")
tool.Name = "Gun"
tool.Parent = game.Players.LocalPlayer.Backpack

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Parent = tool

tool.Activated:Connect(function()
    local bullet = Instance.new("Part")
    bullet.Size = Vector3.new(1,1,3)
    bullet.Position = handle.Position
    bullet.Velocity = handle.CFrame.LookVector * 100
    bullet.Parent = workspace
end)
`;
}

function getMergedTemplate(types) {
    let combined = "-- 🔥 Combined Game Template\n";

    types.forEach(type => {
        if (type === "obby") combined += obbyTemplate();
        if (type === "tycoon") combined += tycoonTemplate();
        if (type === "horror") combined += horrorTemplate();
        if (type === "simulator") combined += simulatorTemplate();
        if (type === "shooter") combined += shooterTemplate();
        if (type === "racing") combined += racingTemplate();

        combined += "\n\n-- 🔀 Next Module\n\n";
    });

    return combined;
}

function getTemplate(type) {
    if (type === "obby") return obbyTemplate();
    if (type === "tycoon") return tycoonTemplate();
    if (type === "horror") return horrorTemplate();
    if (type === "simulator") return simulatorTemplate();
    if (type === "shooter") return shooterTemplate();

    return "";
}


// 🌧️ WOW SYSTEM
function rainEffect() {
    return `
local lighting = game:GetService("Lighting")
lighting.ClockTime = 18
lighting.Brightness = 1

local rain = Instance.new("Part")
rain.Size = Vector3.new(500,1,500)
rain.Position = Vector3.new(0,50,0)
rain.Anchored = true
rain.Transparency = 1
rain.Parent = workspace

local emitter = Instance.new("ParticleEmitter")
emitter.Rate = 500
emitter.Parent = rain
`;
}


// 💬 CONVERSATIONAL SYSTEM
function funSystem() {
    return `
for i = 1,5 do
    local boost = Instance.new("Part")
    boost.Size = Vector3.new(5,1,5)
    boost.Position = Vector3.new(i*10,2,0)
    boost.Anchored = true
    boost.BrickColor = BrickColor.new("Bright yellow")
    boost.Parent = workspace
end
`;
}


// 🚀 MASTER API
app.post("/ai", async (req, res) => {
    const { prompt } = req.body;

    const intent = detectIntent(prompt);

    let message = "";
    let code = "";

    // 🧩 BUILD MODE (Template + AI)
    if (intent === "build") {
        const type = detectGameType(prompt);
        const baseCode = getTemplate(type);

        const aiRes = await openai.chat.completions.create({
            model: "gpt-5.3-chat-latest",
            messages: [
                {
                    role: "system",
                    content: "Expand this Roblox Lua code. Only output code."
                },
                {
                    role: "user",
                    content: prompt + "\nBase:\n" + baseCode
                }
            ]
        });

        code = stripCodeFences(aiRes.choices[0].message.content);
        message = "🚀 Building your game...";
    }

    // 🌧️ WOW MODE
    else if (intent === "wow") {
        code = rainEffect();
        message = "🌧️ Adding rain effect...";
    }

    // 💬 CONVERSATION MODE
    else if (intent === "conversation") {
        code = funSystem();
        message = "Adding fun elements ⚡";
    }

    res.json({ message, code });
});

app.post("/plan", async (req, res) => {
    const prompt = req.body.prompt;
    const fast = req.body.fast !== false;

    // Speed-first mode: return immediate local plan.
    if (fast) {
        return res.json({ plan: quickPlanFromPrompt(prompt) });
    }

    const completion = await openai.chat.completions.create({
        model: "gpt-5.4",
        messages: [
            {
                role: "system",
                content:
                    "You are a Roblox game planner. Output a clear numbered step-by-step plan for building the game in Studio. One step per line. No code. No extra commentary.",
            },
            {
                role: "user",
                content: prompt,
            },
        ],
    });

    const plan = completion.choices[0].message.content;

    res.json({ plan });
});

app.post("/generateStep", async (req, res) => {
    const { prompt, step } = req.body;

    let instruction = "";

    if (step === 1) {
        instruction = "Create basic game structure in Roblox.";
    } else if (step === 2) {
        instruction = "Add core gameplay features.";
    } else if (step === 3) {
        instruction = "Polish game, add UI and improvements.";
    }

    const completion = await openai.chat.completions.create({
        model: "gpt-5.3-chat-latest",
        messages: [
            {
                role: "system",
                content:
                    "You are a Roblox Lua developer writing code that will be executed from a Studio plugin.\n" +
                    "Rules:\n" +
                    "- Output ONLY Lua code.\n" +
                    "- Do NOT use Players.LocalPlayer or game.Players.LocalPlayer.\n" +
                    "- Do NOT use rbxassetid:// sounds (asset permissions may fail). Skip audio.\n" +
                    "- Create only Workspace geometry + safe scripts if needed.\n" +
                    "- No markdown, no explanations."
            },
            {
                role: "user",
                content: `Game idea: ${prompt}\nStep: ${instruction}`
            }
        ]
    });

    res.json({
        message: "⚙️ " + instruction,
        code: stripCodeFences(completion.choices[0].message.content)
    });
});

app.post("/ai-final", async (req, res) => {
    const { prompt } = req.body;
    const fast = req.body.fast !== false;
    const structured = req.body.structured === true;
    const action = req.body.action || "generate";
    const instruction = req.body.instruction || "";
    const previousBuild = req.body.build;

    const types = detectGameTypes(prompt);

    let finalCode = "";
    let plan = "";

    // ✅ STRUCTURED BUILD MODE (preferred: safer than executing AI Lua)
    if (structured) {
        const schemaHint = {
            version: 1,
            rootFolderName: "AI_Build",
            instances: [
                {
                    id: "root",
                    className: "Folder",
                    name: "AI_Build",
                    parent: "workspace",
                    properties: {}
                }
            ]
        };

        const userContent =
            action === "refine"
                ? (
                    "You are refining an existing build.\n" +
                    "Game prompt:\n" + prompt + "\n\n" +
                    "Refine instruction:\n" + instruction + "\n\n" +
                    "Previous build JSON:\n" + JSON.stringify(previousBuild || {}, null, 2) + "\n\n" +
                    "Return the FULL updated build JSON (not a diff)."
                )
                : prompt;

        const aiRes = await openai.chat.completions.create({
            model: "gpt-5.3-chat-latest",
            messages: [
                {
                    role: "system",
                    content:
                        "You output ONLY valid JSON. No markdown. No explanations.\n" +
                        "Return an object with:\n" +
                        "- message: short string\n" +
                        "- build: { version: 1, rootFolderName: 'AI_Build', instances: [...] }\n" +
                        "instances is a flat list. Each instance has:\n" +
                        "- id (string, unique)\n" +
                        "- className (e.g. Part, Folder, SpawnLocation, Model, ScreenGui, TextLabel, BillboardGui, Script, LocalScript)\n" +
                        "- name (optional string)\n" +
                        "- parent (string id, or one of: 'workspace', 'ServerScriptService', 'StarterGui')\n" +
                        "- properties (object of simple values)\n" +
                        "- source (only for Script/LocalScript/ModuleScript)\n" +
                        "Safety rules:\n" +
                        "- Do NOT reference or require existing assets (no rbxassetid sounds).\n" +
                        "- Prefer creating everything under rootFolderName in workspace.\n" +
                        "- If you create UI, put it under StarterGui.\n" +
                        "- If you create server scripts, put under ServerScriptService.\n" +
                        "- Keep IDs stable when refining so objects update predictably.\n" +
                        "Example schema:\n" +
                        JSON.stringify(schemaHint)
                },
                { role: "user", content: userContent }
            ]
        });

        const raw = String(aiRes.choices?.[0]?.message?.content || "").trim();
        const parsed = safeJsonParse(raw);
        if (!parsed.ok) {
            return res.json({
                mode: "structured-error",
                message: "⚠️ Structured mode: invalid JSON; falling back to Lua.",
                structuredError: "Invalid JSON from model",
                code: ""
            });
        }

        const out = parsed.value;
        const v = validateStructuredBuild(out.build);
        if (!v.ok) {
            return res.json({
                mode: "structured-error",
                message: "⚠️ Structured mode: invalid build schema; falling back to Lua.",
                structuredError: v.error,
                code: ""
            });
        }

        return res.json({
            mode: "structured",
            message: out.message || "✅ Structured build ready",
            build: out.build
        });
    }

    // ✅ TEMPLATE FLOW
    if (!types.includes("default")) {

        const mergedTemplate = getMergedTemplate(types);

        const aiRes = await openai.chat.completions.create({
            model: "gpt-5.3-chat-latest",
            messages: [
                {
                    role: "system",
                    content:
                        "You are a senior Roblox Lua developer.\n" +
                        "Improve and merge the provided Lua systems into one cohesive, working result.\n" +
                        "This code will be executed from a Studio plugin (Edit mode).\n" +
                        "Rules:\n" +
                        "- Output ONLY Lua code (no markdown, no backticks, no explanations).\n" +
                        "- Do NOT use Players.LocalPlayer.\n" +
                        "- Do NOT call Instances like functions.\n" +
                        "- Do NOT use rbxassetid:// sounds (asset permissions may fail). Skip audio.\n" +
                        "- Prefer building parts + SpawnLocation + checkpoints + win UI.\n"
                },
                {
                    role: "user",
                    content: prompt + "\nBase:\n" + mergedTemplate
                }
            ]
        });

        finalCode = stripCodeFences(aiRes.choices[0].message.content);

        return res.json({
            mode: "template",
            message: "🚀 Building using smart templates...",
            code: finalCode
        });
    }

    // ❌ NO TEMPLATE → PLANNING FLOW
    else {
        if (fast) {
            // Fast path: avoid two model calls (plan + code). Build plan locally.
            plan = quickPlanFromPrompt(prompt);

            const codeRes = await openai.chat.completions.create({
                model: "gpt-5.3-chat-latest",
                messages: [
                    {
                        role: "system",
                        content:
                            "You are a Roblox Lua developer. " +
                            "Generate concise, working Lua for Studio. " +
                            "Output ONLY Lua code (no markdown, no explanation)."
                    },
                    {
                        role: "user",
                        content:
                            `Game Idea: ${prompt}\n` +
                            `Quick Plan:\n${plan}\n` +
                            "Prefer minimal, runnable code blocks for fast iteration."
                    }
                ]
            });

            finalCode = stripCodeFences(codeRes.choices[0].message.content);

            return res.json({
                mode: "planner-fast",
                message: "⚡ Fast planning + build...",
                plan,
                code: finalCode
            });
        }

        // 🧠 STEP 1: PLAN
        const planRes = await openai.chat.completions.create({
            model: "gpt-5.4",
            messages: [
                {
                    role: "system",
                    content: "Break this game idea into steps."
                },
                {
                    role: "user",
                    content: prompt
                }
            ]
        });

        plan = planRes.choices[0].message.content;

        // 💻 STEP 2: GENERATE CODE FROM PLAN
        const codeRes = await openai.chat.completions.create({
            model: "gpt-5.3-chat-latest",
            messages: [
                {
                    role: "system",
                    content: `You are a Roblox developer.

Generate code step-by-step based on this plan.
Make it structured and working.
Only output Lua code.`
                },
                {
                    role: "user",
                    content: `Game Idea: ${prompt}\nPlan:\n${plan}`
                }
            ]
        });

        finalCode = stripCodeFences(codeRes.choices[0].message.content);

        return res.json({
            mode: "planner",
            message: "🧠 Planning and building from scratch...",
            plan,
            code: finalCode
        });
    }
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log("🔥 Master AI running on", PORT));
