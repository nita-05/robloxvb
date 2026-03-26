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

function structuredTemplateBuildFromPrompt(prompt) {
    const p = String(prompt || "").toLowerCase();
    const isSurvival =
        p.includes("survival") ||
        p.includes("waves") ||
        p.includes("wave") ||
        p.includes("island") ||
        p.includes("enemies") ||
        p.includes("enemy") ||
        p.includes("sword");
    const isFlappy =
        p.includes("flappy") ||
        (p.includes("bird") && p.includes("pipe")) ||
        p.includes("pipes") ||
        p.includes("tap") ||
        p.includes("flap");

    /** @type {any[]} */
    const instances = [
        { id: "root", className: "Folder", name: "AI_Build", parent: "workspace", properties: {} },
    ];

    // Always include a spawn
    instances.push({
        id: "spawn",
        className: "SpawnLocation",
        name: "Spawn",
        parent: "root",
        properties: { Anchored: true, Size: [6, 1, 6], Position: [0, 5, 0] }
    });

    if (isSurvival) {
        // Keep your 2-script structure: one ServerScript + one Client UI script.
        // The server script creates environment + enemies + replicated events.
        // The client script builds UI and wires sword to server.
        instances.push({ id: "envFolder", className: "Folder", name: "SurvivalEnv", parent: "root", properties: {} });
        instances.push({ id: "enemiesFolder", className: "Folder", name: "SurvivalEnemies", parent: "root", properties: {} });

        instances.push({
            id: "survivalServer",
            className: "Script",
            name: "SurvivalGame",
            parent: "ServerScriptService",
            properties: {},
            source:
                "-- Survival Game (Server)\n" +
                "-- Auto-generated template based on your provided SurvivalGame.server.lua\n\n" +
                "local Players = game:GetService(\"Players\")\n" +
                "local Workspace = game:GetService(\"Workspace\")\n" +
                "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\n" +
                "local Lighting = game:GetService(\"Lighting\")\n\n" +
                "local WAVE_INTERVAL = 30\n" +
                "local ENEMIES_PER_WAVE_BASE = 3\n" +
                "local ENEMY_HP_BASE = 25\n" +
                "local ENEMY_DAMAGE = 10\n" +
                "local ENEMY_TOUCH_COOLDOWN = 1.5\n" +
                "local SWORD_DAMAGE = 35\n" +
                "local SWORD_RANGE = 12\n" +
                "local DAY_NIGHT_CYCLE_SPEED = 1 / 120\n\n" +
                "local function ensureFolder(parent, name)\n" +
                "\tlocal f = parent:FindFirstChild(name)\n" +
                "\tif not f then\n" +
                "\t\tf = Instance.new(\"Folder\")\n" +
                "\t\tf.Name = name\n" +
                "\t\tf.Parent = parent\n" +
                "\tend\n" +
                "\treturn f\n" +
                "end\n\n" +
                "-- Use AI_Build roots if present\n" +
                "local root = Workspace:FindFirstChild(\"AI_Build\") or Workspace\n" +
                "local envFolder = ensureFolder(root, \"SurvivalEnv\")\n" +
                "local enemiesFolder = ensureFolder(root, \"SurvivalEnemies\")\n\n" +
                "local function applyLighting()\n" +
                "\tif Lighting:GetAttribute(\"SurvivalLightingApplied\") then return end\n" +
                "\tLighting:SetAttribute(\"SurvivalLightingApplied\", true)\n" +
                "\tlocal atm = Lighting:FindFirstChild(\"SurvivalAtmosphere\")\n" +
                "\tif not atm then\n" +
                "\t\tatm = Instance.new(\"Atmosphere\")\n" +
                "\t\tatm.Name = \"SurvivalAtmosphere\"\n" +
                "\t\tatm.Density = 0.3\n" +
                "\t\tatm.Offset = 0\n" +
                "\t\tatm.Color = Color3.fromRGB(199, 170, 107)\n" +
                "\t\tatm.Decay = Color3.fromRGB(92, 70, 44)\n" +
                "\t\tatm.Glare = 0\n" +
                "\t\tatm.Haze = 0.2\n" +
                "\t\tatm.Parent = Lighting\n" +
                "\tend\n" +
                "\tLighting.FogEnd = 1000\n" +
                "\tLighting.FogStart = 0\n" +
                "\tLighting.GlobalShadows = true\n" +
                "\ttask.spawn(function()\n" +
                "\t\twhile Lighting.Parent do\n" +
                "\t\t\tLighting.ClockTime = (Lighting.ClockTime + DAY_NIGHT_CYCLE_SPEED) % 24\n" +
                "\t\t\ttask.wait(1)\n" +
                "\t\tend\n" +
                "\tend)\n" +
                "end\n\n" +
                "local function buildIsland()\n" +
                "\tif envFolder:GetAttribute(\"Built\") then return end\n" +
                "\tenvFolder:SetAttribute(\"Built\", true)\n" +
                "\tlocal ground = Instance.new(\"Part\")\n" +
                "\tground.Name = \"Island\"\n" +
                "\tground.Size = Vector3.new(120, 4, 120)\n" +
                "\tground.Position = Vector3.new(0, 2, 0)\n" +
                "\tground.Anchored = true\n" +
                "\tground.Material = Enum.Material.Grass\n" +
                "\tground.Color = Color3.fromRGB(60, 140, 80)\n" +
                "\tground.Parent = envFolder\n" +
                "\tfor i = 1, 8 do\n" +
                "\t\tlocal angle = (i / 8) * math.pi * 2\n" +
                "\t\tlocal r = 50 + math.random(10, 25)\n" +
                "\t\tlocal x, z = math.cos(angle) * r, math.sin(angle) * r\n" +
                "\t\tlocal rock = Instance.new(\"Part\")\n" +
                "\t\trock.Name = \"Rock\"\n" +
                "\t\trock.Size = Vector3.new(math.random(6, 14), math.random(4, 10), math.random(6, 14))\n" +
                "\t\trock.Position = Vector3.new(x, 2 + rock.Size.Y / 2, z)\n" +
                "\t\trock.Anchored = true\n" +
                "\t\trock.Material = Enum.Material.Slate\n" +
                "\t\trock.Color = Color3.fromRGB(90, 90, 95)\n" +
                "\t\trock.Parent = envFolder\n" +
                "\tend\n" +
                "\tfor i = 1, 12 do\n" +
                "\t\tlocal x, z = math.random(-40, 40), math.random(-40, 40)\n" +
                "\t\tlocal trunk = Instance.new(\"Part\")\n" +
                "\t\ttrunk.Name = \"Trunk\"\n" +
                "\t\ttrunk.Size = Vector3.new(2, 8, 2)\n" +
                "\t\ttrunk.Position = Vector3.new(x, 6, z)\n" +
                "\t\ttrunk.Anchored = true\n" +
                "\t\ttrunk.Material = Enum.Material.Wood\n" +
                "\t\ttrunk.Color = Color3.fromRGB(90, 60, 40)\n" +
                "\t\ttrunk.Parent = envFolder\n" +
                "\t\tlocal top = Instance.new(\"Part\")\n" +
                "\t\ttop.Shape = Enum.PartType.Ball\n" +
                "\t\ttop.Name = \"Canopy\"\n" +
                "\t\ttop.Size = Vector3.new(6, 6, 6)\n" +
                "\t\ttop.Position = Vector3.new(x, 12, z)\n" +
                "\t\ttop.Anchored = true\n" +
                "\t\ttop.Material = Enum.Material.Grass\n" +
                "\t\ttop.Color = Color3.fromRGB(30, 100, 50)\n" +
                "\t\ttop.Parent = envFolder\n" +
                "\tend\n" +
                "\tlocal spawnLoc = envFolder:FindFirstChildOfClass(\"SpawnLocation\")\n" +
                "\tif not spawnLoc then\n" +
                "\t\tspawnLoc = Instance.new(\"SpawnLocation\")\n" +
                "\t\tspawnLoc.Name = \"SurvivalSpawn\"\n" +
                "\t\tspawnLoc.Size = Vector3.new(8, 1, 8)\n" +
                "\t\tspawnLoc.Position = Vector3.new(0, 5, 0)\n" +
                "\t\tspawnLoc.Anchored = true\n" +
                "\t\tspawnLoc.Transparency = 1\n" +
                "\t\tspawnLoc.CanCollide = false\n" +
                "\t\tspawnLoc.Parent = envFolder\n" +
                "\tend\n" +
                "\tspawnLoc.Position = Vector3.new(0, 5, 0)\n" +
                "\tspawnLoc.Anchored = true\n" +
                "end\n\n" +
                "local function ensureLeaderstats(plr)\n" +
                "\tlocal ls = plr:FindFirstChild(\"leaderstats\")\n" +
                "\tif not ls then\n" +
                "\t\tls = Instance.new(\"Folder\")\n" +
                "\t\tls.Name = \"leaderstats\"\n" +
                "\t\tls.Parent = plr\n" +
                "\tend\n" +
                "\tif not ls:FindFirstChild(\"SurvivalTime\") then\n" +
                "\t\tlocal t = Instance.new(\"IntValue\")\n" +
                "\t\tt.Name = \"SurvivalTime\"\n" +
                "\t\tt.Value = 0\n" +
                "\t\tt.Parent = ls\n" +
                "\tend\n" +
                "\tif not ls:FindFirstChild(\"Kills\") then\n" +
                "\t\tlocal k = Instance.new(\"IntValue\")\n" +
                "\t\tk.Name = \"Kills\"\n" +
                "\t\tk.Value = 0\n" +
                "\t\tk.Parent = ls\n" +
                "\tend\n" +
                "\treturn ls\n" +
                "end\n\n" +
                "local function getWaveState()\n" +
                "\tlocal f = ReplicatedStorage:FindFirstChild(\"SurvivalWave\")\n" +
                "\tif not f then\n" +
                "\t\tf = Instance.new(\"Folder\")\n" +
                "\t\tf.Name = \"SurvivalWave\"\n" +
                "\t\tf.Parent = ReplicatedStorage\n" +
                "\t\tlocal n = Instance.new(\"IntValue\")\n" +
                "\t\tn.Name = \"Number\"\n" +
                "\t\tn.Value = 0\n" +
                "\t\tn.Parent = f\n" +
                "\tend\n" +
                "\treturn f\n" +
                "end\n\n" +
                "local function createEnemy(spawnPos, waveNumber)\n" +
                "\tlocal model = Instance.new(\"Model\")\n" +
                "\tmodel.Name = \"Enemy\"\n" +
                "\tlocal humanoid = Instance.new(\"Humanoid\")\n" +
                "\thumanoid.MaxHealth = ENEMY_HP_BASE + waveNumber * 5\n" +
                "\thumanoid.Health = humanoid.MaxHealth\n" +
                "\thumanoid.WalkSpeed = 10\n" +
                "\thumanoid.Parent = model\n" +
                "\tlocal part = Instance.new(\"Part\")\n" +
                "\tpart.Name = \"HumanoidRootPart\"\n" +
                "\tpart.Size = Vector3.new(2, 5, 1)\n" +
                "\tpart.Position = spawnPos\n" +
                "\tpart.Anchored = false\n" +
                "\tpart.CanCollide = true\n" +
                "\tpart.Material = Enum.Material.Neon\n" +
                "\tpart.Color = Color3.fromRGB(200, 50, 50)\n" +
                "\tpart.Parent = model\n" +
                "\tmodel.PrimaryPart = part\n" +
                "\tmodel.Parent = enemiesFolder\n" +
                "\tlocal lastTouch = {}\n" +
                "\tpart.Touched:Connect(function(hit)\n" +
                "\t\tlocal char = hit:FindFirstAncestorOfClass(\"Model\")\n" +
                "\t\tlocal plr = char and Players:GetPlayerFromCharacter(char)\n" +
                "\t\tif not plr or plr == model then return end\n" +
                "\t\tlocal now = tick()\n" +
                "\t\tif lastTouch[plr] and (now - lastTouch[plr]) < ENEMY_TOUCH_COOLDOWN then return end\n" +
                "\t\tlastTouch[plr] = now\n" +
                "\t\tlocal h = char:FindFirstChildOfClass(\"Humanoid\")\n" +
                "\t\tif h and h.Health > 0 then h:TakeDamage(ENEMY_DAMAGE) end\n" +
                "\tend)\n" +
                "\thumanoid.Died:Connect(function()\n" +
                "\t\tlocal killer = humanoid:GetAttribute(\"Killer\")\n" +
                "\t\tif killer then\n" +
                "\t\t\tlocal k = ensureLeaderstats(killer):FindFirstChild(\"Kills\")\n" +
                "\t\t\tif k then k.Value = k.Value + 1 end\n" +
                "\t\tend\n" +
                "\t\ttask.delay(2, function() if model.Parent then model:Destroy() end end)\n" +
                "\tend)\n" +
                "\treturn model\n" +
                "end\n\n" +
                "local waveNumber = 0\n" +
                "local function spawnWave()\n" +
                "\twaveNumber += 1\n" +
                "\tlocal stateFolder = getWaveState()\n" +
                "\tlocal numVal = stateFolder:FindFirstChild(\"Number\")\n" +
                "\tif numVal then numVal.Value = waveNumber end\n" +
                "\tlocal count = ENEMIES_PER_WAVE_BASE + math.floor(waveNumber / 2)\n" +
                "\tfor i = 1, count do\n" +
                "\t\ttask.spawn(function()\n" +
                "\t\t\tlocal angle = math.random() * math.pi * 2\n" +
                "\t\t\tlocal r = 25 + math.random(5, 35)\n" +
                "\t\t\tlocal x, z = math.cos(angle) * r, math.sin(angle) * r\n" +
                "\t\t\tlocal pos = Vector3.new(x, 6, z)\n" +
                "\t\t\tlocal enemy = createEnemy(pos, waveNumber)\n" +
                "\t\t\tlocal hum = enemy:FindFirstChildOfClass(\"Humanoid\")\n" +
                "\t\t\tlocal rootPart = enemy.PrimaryPart\n" +
                "\t\t\tif not hum or not rootPart then return end\n" +
                "\t\t\twhile enemy.Parent and hum.Health > 0 do\n" +
                "\t\t\t\tlocal nearest = nil\n" +
                "\t\t\t\tlocal dist = 9999\n" +
                "\t\t\t\tfor _, p2 in ipairs(Players:GetPlayers()) do\n" +
                "\t\t\t\t\tif p2.Character and p2.Character:FindFirstChild(\"HumanoidRootPart\") then\n" +
                "\t\t\t\t\t\tlocal hrp = p2.Character.HumanoidRootPart\n" +
                "\t\t\t\t\t\tlocal d = (hrp.Position - rootPart.Position).Magnitude\n" +
                "\t\t\t\t\t\tif d < dist then dist = d; nearest = hrp end\n" +
                "\t\t\t\t\tend\n" +
                "\t\t\t\tend\n" +
                "\t\t\t\tif nearest then hum:MoveTo(nearest.Position) end\n" +
                "\t\t\t\ttask.wait(1)\n" +
                "\t\t\tend\n" +
                "\t\tend)\n" +
                "\tend\n" +
                "end\n\n" +
                "local events = ensureFolder(ReplicatedStorage, \"SurvivalEvents\")\n" +
                "local swordHit = events:FindFirstChild(\"SwordHit\")\n" +
                "if not swordHit then\n" +
                "\tswordHit = Instance.new(\"RemoteEvent\")\n" +
                "\tswordHit.Name = \"SwordHit\"\n" +
                "\tswordHit.Parent = events\n" +
                "end\n\n" +
                "swordHit.OnServerEvent:Connect(function(plr, targetPos)\n" +
                "\tif not plr.Character then return end\n" +
                "\tlocal rootPart = plr.Character:FindFirstChild(\"HumanoidRootPart\")\n" +
                "\tif not rootPart then return end\n" +
                "\tlocal tp = Vector3.new(targetPos.x or 0, targetPos.y or 0, targetPos.z or 0)\n" +
                "\tif (tp - rootPart.Position).Magnitude > SWORD_RANGE + 10 then return end\n" +
                "\tfor _, m in ipairs(enemiesFolder:GetChildren()) do\n" +
                "\t\tif m:IsA(\"Model\") and m.PrimaryPart then\n" +
                "\t\t\tlocal d = (m.PrimaryPart.Position - rootPart.Position).Magnitude\n" +
                "\t\t\tif d <= SWORD_RANGE then\n" +
                "\t\t\t\tlocal hum = m:FindFirstChildOfClass(\"Humanoid\")\n" +
                "\t\t\t\tif hum and hum.Health > 0 then\n" +
                "\t\t\t\t\thum:TakeDamage(SWORD_DAMAGE)\n" +
                "\t\t\t\t\thum:SetAttribute(\"Killer\", plr)\n" +
                "\t\t\t\t\tbreak\n" +
                "\t\t\t\tend\n" +
                "\t\t\tend\n" +
                "\t\tend\n" +
                "\tend\n" +
                "end)\n\n" +
                "local function giveSword(plr)\n" +
                "\tlocal backpack = plr:FindFirstChild(\"Backpack\")\n" +
                "\tif not backpack then return end\n" +
                "\tlocal existing = plr:FindFirstChild(\"Sword\") or backpack:FindFirstChild(\"Sword\")\n" +
                "\tif existing then return end\n" +
                "\tlocal tool = Instance.new(\"Tool\")\n" +
                "\ttool.Name = \"Sword\"\n" +
                "\ttool.RequiresHandle = true\n" +
                "\ttool.CanBeDropped = false\n" +
                "\tlocal handle = Instance.new(\"Part\")\n" +
                "\thandle.Name = \"Handle\"\n" +
                "\thandle.Size = Vector3.new(0.5, 4, 0.3)\n" +
                "\thandle.Color = Color3.fromRGB(100, 100, 110)\n" +
                "\thandle.Material = Enum.Material.Metal\n" +
                "\thandle.Parent = tool\n" +
                "\ttool.Parent = backpack\n" +
                "end\n\n" +
                "local timerConnections = {}\n" +
                "local function startSurvivalTimer(plr)\n" +
                "\tif timerConnections[plr] then return end\n" +
                "\tlocal ls = ensureLeaderstats(plr)\n" +
                "\tlocal survivalVal = ls:FindFirstChild(\"SurvivalTime\")\n" +
                "\tif not survivalVal then return end\n" +
                "\ttimerConnections[plr] = true\n" +
                "\ttask.spawn(function()\n" +
                "\t\twhile plr.Parent and survivalVal.Parent do\n" +
                "\t\t\ttask.wait(1)\n" +
                "\t\t\tif not plr.Parent or not survivalVal.Parent then break end\n" +
                "\t\t\tsurvivalVal.Value += 1\n" +
                "\t\tend\n" +
                "\t\ttimerConnections[plr] = nil\n" +
                "\tend)\n" +
                "end\n\n" +
                "Players.PlayerAdded:Connect(function(plr)\n" +
                "\tensureLeaderstats(plr)\n" +
                "\tplr.CharacterAdded:Connect(function(char)\n" +
                "\t\tlocal hrp = char:WaitForChild(\"HumanoidRootPart\", 5)\n" +
                "\t\tif hrp then hrp.CFrame = CFrame.new(0, 8, 0) end\n" +
                "\t\ttask.delay(0.5, function() if plr.Parent then giveSword(plr) end end)\n" +
                "\t\tstartSurvivalTimer(plr)\n" +
                "\tend)\n" +
                "\tif plr.Character then\n" +
                "\t\tlocal hrp = plr.Character:FindFirstChild(\"HumanoidRootPart\")\n" +
                "\t\tif hrp then hrp.CFrame = CFrame.new(0, 8, 0) end\n" +
                "\t\ttask.delay(0.5, function() if plr.Parent then giveSword(plr) end end)\n" +
                "\t\tstartSurvivalTimer(plr)\n" +
                "\tend\n" +
                "end)\n\n" +
                "applyLighting()\n" +
                "buildIsland()\n" +
                "task.wait(2)\n" +
                "while true do\n" +
                "\tspawnWave()\n" +
                "\ttask.wait(WAVE_INTERVAL)\n" +
                "end\n"
        });

        instances.push({
            id: "survivalClient",
            className: "LocalScript",
            name: "SurvivalUI",
            parent: "StarterPlayerScripts",
            properties: {},
            source:
                "-- Survival Game UI (Client)\n" +
                "-- Auto-generated template based on your provided client UI script\n\n" +
                "local Players = game:GetService(\"Players\")\n" +
                "local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")\n" +
                "local RunService = game:GetService(\"RunService\")\n\n" +
                "local player = Players.LocalPlayer\n" +
                "local playerGui = player:WaitForChild(\"PlayerGui\")\n\n" +
                "local leaderstats = player:WaitForChild(\"leaderstats\", 15)\n" +
                "local survivalTimeVal = leaderstats and leaderstats:WaitForChild(\"SurvivalTime\", 5)\n" +
                "local killsVal = leaderstats and leaderstats:WaitForChild(\"Kills\", 5)\n\n" +
                "local waveFolder = ReplicatedStorage:WaitForChild(\"SurvivalWave\", 10)\n" +
                "local waveNumberVal = waveFolder and waveFolder:FindFirstChild(\"Number\")\n\n" +
                "local events = ReplicatedStorage:WaitForChild(\"SurvivalEvents\", 10)\n" +
                "local swordHit = events and events:FindFirstChild(\"SwordHit\")\n\n" +
                "local gui = Instance.new(\"ScreenGui\")\n" +
                "gui.Name = \"SurvivalUI\"\n" +
                "gui.ResetOnSpawn = false\n" +
                "gui.DisplayOrder = 10\n" +
                "gui.IgnoreGuiInset = true\n" +
                "gui.Parent = playerGui\n\n" +
                "local main = Instance.new(\"Frame\")\n" +
                "main.AnchorPoint = Vector2.new(0, 0)\n" +
                "main.Size = UDim2.new(0, 260, 0, 140)\n" +
                "main.Position = UDim2.new(0, 16, 0, 16)\n" +
                "main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)\n" +
                "main.BackgroundTransparency = 0.2\n" +
                "main.BorderSizePixel = 0\n" +
                "main.ClipsDescendants = true\n" +
                "main.Parent = gui\n\n" +
                "local corner = Instance.new(\"UICorner\")\n" +
                "corner.CornerRadius = UDim.new(0, 8)\n" +
                "corner.Parent = main\n\n" +
                "local function label(parent, text, y)\n" +
                "\tlocal l = Instance.new(\"TextLabel\")\n" +
                "\tl.Size = UDim2.new(1, -20, 0, 28)\n" +
                "\tl.Position = UDim2.new(0, 10, 0, y)\n" +
                "\tl.BackgroundTransparency = 1\n" +
                "\tl.Text = text\n" +
                "\tl.TextColor3 = Color3.new(1, 1, 1)\n" +
                "\tl.TextSize = 18\n" +
                "\tl.Font = Enum.Font.GothamBold\n" +
                "\tl.TextXAlignment = Enum.TextXAlignment.Left\n" +
                "\tl.Parent = parent\n" +
                "\treturn l\n" +
                "end\n\n" +
                "local survivalLabel = label(main, \"Survival: 0:00\", 8)\n" +
                "local killsLabel = label(main, \"Kills: 0\", 38)\n" +
                "local waveLabel = label(main, \"Wave: 1\", 68)\n" +
                "local hpLabel = label(main, \"HP: 100\", 98)\n\n" +
                "local function formatTime(sec)\n" +
                "\tlocal m = math.floor(sec / 60)\n" +
                "\tlocal s = sec % 60\n" +
                "\treturn string.format(\"%d:%02d\", m, s)\n" +
                "end\n\n" +
                "local function hpColor(pct)\n" +
                "\tif pct > 0.5 then\n" +
                "\t\treturn Color3.fromRGB(80, 220, 100)\n" +
                "\telseif pct > 0.2 then\n" +
                "\t\treturn Color3.fromRGB(240, 200, 60)\n" +
                "\telse\n" +
                "\t\treturn Color3.fromRGB(255, 80, 80)\n" +
                "\tend\n" +
                "end\n\n" +
                "local lastSurvivalValue = 0\n" +
                "local lastSurvivalTick = 0\n" +
                "if survivalTimeVal then\n" +
                "\tlastSurvivalValue = survivalTimeVal.Value\n" +
                "\tlastSurvivalTick = tick()\n" +
                "\tsurvivalTimeVal:GetPropertyChangedSignal(\"Value\"):Connect(function()\n" +
                "\t\tlastSurvivalValue = survivalTimeVal.Value\n" +
                "\t\tlastSurvivalTick = tick()\n" +
                "\tend)\n" +
                "end\n\n" +
                "local function getDisplayHealth(char)\n" +
                "\tlocal hum = char and char:FindFirstChildOfClass(\"Humanoid\")\n" +
                "\tif not hum then return nil, nil end\n" +
                "\tlocal dead = hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead\n" +
                "\treturn dead and 0 or hum.Health, hum.MaxHealth\n" +
                "end\n\n" +
                "RunService.Heartbeat:Connect(function()\n" +
                "\tlocal now = tick()\n" +
                "\tif survivalTimeVal then\n" +
                "\t\tlocal smoothSec = lastSurvivalValue + (now - lastSurvivalTick)\n" +
                "\t\tsurvivalLabel.Text = \"Survival: \" .. formatTime(smoothSec)\n" +
                "\tend\n" +
                "\tif killsVal then killsLabel.Text = \"Kills: \" .. tostring(killsVal.Value) end\n" +
                "\tif waveNumberVal then waveLabel.Text = \"Wave: \" .. tostring(waveNumberVal.Value) end\n" +
                "\tlocal char = player.Character\n" +
                "\tlocal health, maxHealth = getDisplayHealth(char)\n" +
                "\tif health ~= nil and maxHealth and maxHealth > 0 then\n" +
                "\t\tlocal pct = health / maxHealth\n" +
                "\t\tif health <= 0 then\n" +
                "\t\t\thpLabel.Text = \"HP: 0 (Dead)\"\n" +
                "\t\t\thpLabel.TextColor3 = Color3.fromRGB(255, 80, 80)\n" +
                "\t\telse\n" +
                "\t\t\thpLabel.Text = \"HP: \" .. math.floor(health) .. \" / \" .. math.floor(maxHealth)\n" +
                "\t\t\thpLabel.TextColor3 = hpColor(pct)\n" +
                "\t\tend\n" +
                "\telse\n" +
                "\t\thpLabel.Text = \"HP: --\"\n" +
                "\t\thpLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)\n" +
                "\tend\n" +
                "end)\n\n" +
                "local connectedTools = {}\n" +
                "local function connectSword(tool)\n" +
                "\tif not swordHit or connectedTools[tool] then return end\n" +
                "\tconnectedTools[tool] = true\n" +
                "\ttool.Activated:Connect(function()\n" +
                "\t\tlocal char = player.Character\n" +
                "\t\tlocal root = char and char:FindFirstChild(\"HumanoidRootPart\")\n" +
                "\t\tif root then swordHit:FireServer(root.Position + root.CFrame.LookVector * 5) end\n" +
                "\tend)\n" +
                "\ttool.AncestryChanged:Connect(function(_, parent)\n" +
                "\t\tif not parent then connectedTools[tool] = nil end\n" +
                "\tend)\n" +
                "end\n\n" +
                "local function onCharacterAdded(char)\n" +
                "\tfor _, child in ipairs(char:GetChildren()) do\n" +
                "\t\tif child:IsA(\"Tool\") and child.Name == \"Sword\" then connectSword(child) end\n" +
                "\tend\n" +
                "\tchar.ChildAdded:Connect(function(child)\n" +
                "\t\tif child:IsA(\"Tool\") and child.Name == \"Sword\" then connectSword(child) end\n" +
                "\tend)\n" +
                "end\n\n" +
                "player.CharacterAdded:Connect(onCharacterAdded)\n" +
                "if player.Character then onCharacterAdded(player.Character) end\n"
        });

        return {
            message: "⚡ Instant template build (survival waves + sword + UI)",
            build: { version: 1, rootFolderName: "AI_Build", instances }
        };
    }

    if (isFlappy) {
        // Flappy is entirely client-side UI/logic. Keep as a single LocalScript in StarterPlayerScripts.
        // Disable sound IDs to avoid asset permission failures by default.
        instances.push({
            id: "flappyClient",
            className: "LocalScript",
            name: "FlappyClient",
            parent: "StarterPlayerScripts",
            properties: {},
            source:
                "-- VIBE FLAPPY (Client)\n" +
                "-- Auto-generated template from your provided script.\n" +
                "-- Sounds are disabled by default to avoid asset permission errors.\n\n" +
                "print(\"Flappy script loading...\")\n\n" +
                "local player = game.Players.LocalPlayer\n" +
                "local UIS = game:GetService(\"UserInputService\")\n" +
                "local RunService = game:GetService(\"RunService\")\n\n" +
                "local THEMES = {\n" +
                "\tDefault = {\n" +
                "\t\tSkyColor = Color3.fromRGB(120, 200, 255),\n" +
                "\t\tGroundColor = Color3.fromRGB(80, 200, 120),\n" +
                "\t\tBirdColor = Color3.fromRGB(255, 230, 0),\n" +
                "\t\tPipeColor = Color3.fromRGB(0, 200, 0),\n" +
                "\t\tTextColor = Color3.new(1, 1, 1),\n" +
                "\t},\n" +
                "}\n\n" +
                "local SELECTED_THEME = \"Default\"\n" +
                "local function getTheme(name) return THEMES[name] or THEMES.Default end\n" +
                "local CURRENT_THEME = getTheme(SELECTED_THEME)\n\n" +
                "local function roundCorner(obj, radiusScale)\n" +
                "\tlocal c = Instance.new(\"UICorner\")\n" +
                "\tc.CornerRadius = UDim.new(radiusScale or 0.5, 0)\n" +
                "\tc.Parent = obj\n" +
                "\treturn c\n" +
                "end\n\n" +
                "local state = \"Idle\"\n" +
                "local playTime = 0\n" +
                "local BIRD_X = 0.22\n" +
                "local BIRD_Y_IDLE = 0.28\n\n" +
                "local gui = Instance.new(\"ScreenGui\")\n" +
                "gui.Name = \"FlappyGui\"\n" +
                "gui.IgnoreGuiInset = true\n" +
                "gui.ResetOnSpawn = false\n" +
                "gui.DisplayOrder = 100\n" +
                "gui.Parent = player:WaitForChild(\"PlayerGui\")\n\n" +
                "-- Sounds disabled (set your own IDs if you want)\n" +
                "local SOUND_IDS = { Jump = \"\", Score = \"\", Star = \"\", GameOver = \"\", Countdown = \"\" }\n" +
                "local soundCache = {}\n" +
                "local function playSound(name)\n" +
                "\tlocal id = SOUND_IDS[name]\n" +
                "\tif not id or id == \"\" then return end\n" +
                "\tlocal s = soundCache[name]\n" +
                "\tif not s then\n" +
                "\t\ts = Instance.new(\"Sound\")\n" +
                "\t\ts.SoundId = id\n" +
                "\t\ts.Volume = 0.6\n" +
                "\t\ts.Parent = gui\n" +
                "\t\tsoundCache[name] = s\n" +
                "\tend\n" +
                "\tpcall(function() s:Play() end)\n" +
                "end\n\n" +
                "local canvas = Instance.new(\"Frame\")\n" +
                "canvas.Size = UDim2.new(1, 0, 1, 0)\n" +
                "canvas.BackgroundTransparency = 1\n" +
                "canvas.Parent = gui\n\n" +
                "local skyBg = Instance.new(\"Frame\")\n" +
                "skyBg.Name = \"SkyBg\"\n" +
                "skyBg.Size = UDim2.new(1, 0, 1, 0)\n" +
                "skyBg.Position = UDim2.new(0, 0, 0, 0)\n" +
                "skyBg.BackgroundColor3 = CURRENT_THEME.SkyColor\n" +
                "skyBg.BorderSizePixel = 0\n" +
                "skyBg.Parent = canvas\n\n" +
                "local ground = Instance.new(\"Frame\")\n" +
                "ground.Name = \"Ground\"\n" +
                "ground.Size = UDim2.new(1, 0, 0.15, 0)\n" +
                "ground.Position = UDim2.new(0, 0, 0.85, 0)\n" +
                "ground.BackgroundColor3 = CURRENT_THEME.GroundColor\n" +
                "ground.BorderSizePixel = 0\n" +
                "ground.Parent = canvas\n\n" +
                "-- Bird container\n" +
                "local birdContainer = Instance.new(\"Frame\")\n" +
                "birdContainer.Name = \"Bird\"\n" +
                "birdContainer.Size = UDim2.new(0.06, 0, 0.06, 0)\n" +
                "birdContainer.Position = UDim2.new(BIRD_X, 0, BIRD_Y_IDLE, 0)\n" +
                "birdContainer.AnchorPoint = Vector2.new(0.5, 0.5)\n" +
                "birdContainer.BackgroundTransparency = 1\n" +
                "birdContainer.Parent = canvas\n\n" +
                "local body = Instance.new(\"Frame\")\n" +
                "body.Name = \"Body\"\n" +
                "body.Size = UDim2.new(1, 0, 1, 0)\n" +
                "body.BackgroundColor3 = CURRENT_THEME.BirdColor\n" +
                "body.BorderSizePixel = 0\n" +
                "roundCorner(body, 0.5)\n" +
                "body.Parent = birdContainer\n\n" +
                "local eye = Instance.new(\"Frame\")\n" +
                "eye.Name = \"Eye\"\n" +
                "eye.Size = UDim2.new(0.4, 0, 0.4, 0)\n" +
                "eye.Position = UDim2.new(0.52, 0, 0.15, 0)\n" +
                "eye.BackgroundColor3 = Color3.fromRGB(30, 30, 30)\n" +
                "eye.BorderSizePixel = 0\n" +
                "roundCorner(eye, 0.5)\n" +
                "eye.Parent = birdContainer\n\n" +
                "local beak = Instance.new(\"Frame\")\n" +
                "beak.Name = \"Beak\"\n" +
                "beak.Size = UDim2.new(0.5, 0, 0.22, 0)\n" +
                "beak.Position = UDim2.new(0.75, 0, 0.38, 0)\n" +
                "beak.AnchorPoint = Vector2.new(0, 0.5)\n" +
                "beak.BackgroundColor3 = Color3.fromRGB(240, 140, 0)\n" +
                "beak.BorderSizePixel = 0\n" +
                "beak.Rotation = -5\n" +
                "roundCorner(beak, 0.2)\n" +
                "beak.Parent = birdContainer\n\n" +
                "-- Basic UI buttons\n" +
                "local tapButton = Instance.new(\"TextButton\")\n" +
                "tapButton.Name = \"TapButton\"\n" +
                "tapButton.Size = UDim2.new(0.2, 0, 0.08, 0)\n" +
                "tapButton.Position = UDim2.new(0.78, 0, 0.78, 0)\n" +
                "tapButton.AnchorPoint = Vector2.new(0.5, 0.5)\n" +
                "tapButton.BackgroundColor3 = Color3.fromRGB(80, 180, 100)\n" +
                "tapButton.BorderSizePixel = 0\n" +
                "tapButton.Text = \"TAP\"\n" +
                "tapButton.TextColor3 = Color3.new(1, 1, 1)\n" +
                "tapButton.TextScaled = true\n" +
                "tapButton.Visible = false\n" +
                "tapButton.Parent = canvas\n" +
                "roundCorner(tapButton, 0.4)\n\n" +
                "local startButton = Instance.new(\"TextButton\")\n" +
                "startButton.Name = \"StartButton\"\n" +
                "startButton.Size = UDim2.new(0.22, 0, 0.07, 0)\n" +
                "startButton.Position = UDim2.new(0.5, 0, 0.40, 0)\n" +
                "startButton.AnchorPoint = Vector2.new(0.5, 0.5)\n" +
                "startButton.BackgroundColor3 = Color3.fromRGB(80, 180, 100)\n" +
                "startButton.BorderSizePixel = 0\n" +
                "startButton.Text = \"START\"\n" +
                "startButton.TextColor3 = Color3.new(1, 1, 1)\n" +
                "startButton.TextScaled = true\n" +
                "startButton.Parent = canvas\n" +
                "roundCorner(startButton, 0.4)\n\n" +
                "local restartButton = Instance.new(\"TextButton\")\n" +
                "restartButton.Name = \"RestartButton\"\n" +
                "restartButton.Size = UDim2.new(0.26, 0, 0.07, 0)\n" +
                "restartButton.Position = UDim2.new(0.5, 0, 0.4, 0)\n" +
                "restartButton.AnchorPoint = Vector2.new(0.5, 0.5)\n" +
                "restartButton.BackgroundColor3 = Color3.fromRGB(240, 240, 240)\n" +
                "restartButton.BorderSizePixel = 0\n" +
                "restartButton.Text = \"RESTART\"\n" +
                "restartButton.TextColor3 = Color3.fromRGB(40, 40, 40)\n" +
                "restartButton.TextScaled = true\n" +
                "restartButton.Visible = false\n" +
                "restartButton.Parent = canvas\n" +
                "roundCorner(restartButton, 0.4)\n\n" +
                "-- Minimal gameplay loop (pipes + score)\n" +
                "local gravity = 0.0018\n" +
                "local jumpForce = -0.032\n" +
                "local maxFallSpeed = 0.045\n" +
                "local velocity = 0\n" +
                "local pipes = {}\n" +
                "local pipeSpeed = 0.004\n" +
                "local pipeWidth = 0.1\n" +
                "local GAP_SCALE = 0.22\n" +
                "local score = 0\n\n" +
                "local scoreLabel = Instance.new(\"TextLabel\")\n" +
                "scoreLabel.Size = UDim2.new(0.2, 0, 0.08, 0)\n" +
                "scoreLabel.Position = UDim2.new(0.5, 0, 0.02, 0)\n" +
                "scoreLabel.AnchorPoint = Vector2.new(0.5, 0)\n" +
                "scoreLabel.BackgroundTransparency = 1\n" +
                "scoreLabel.TextScaled = true\n" +
                "scoreLabel.TextColor3 = CURRENT_THEME.TextColor\n" +
                "scoreLabel.Text = \"0\"\n" +
                "scoreLabel.Parent = canvas\n\n" +
                "local function createPipe(spawnX)\n" +
                "\tlocal centerY = (math.random(38, 62)) / 100\n" +
                "\tcenterY = math.clamp(centerY, 0.3, 0.65)\n" +
                "\tlocal gap = math.clamp(GAP_SCALE * (0.95 + math.random() * 0.15), 0.16, 0.28)\n" +
                "\tlocal topHeight = centerY - gap / 2\n" +
                "\tlocal bottomY = centerY + gap / 2\n" +
                "\tlocal bottomHeight = 1 - bottomY\n\n" +
                "\tlocal top = Instance.new(\"Frame\")\n" +
                "\ttop.Name = \"PipeTop\"\n" +
                "\ttop.Size = UDim2.new(pipeWidth, 0, topHeight, 0)\n" +
                "\ttop.Position = UDim2.new(spawnX, 0, 0, 0)\n" +
                "\ttop.BackgroundColor3 = CURRENT_THEME.PipeColor\n" +
                "\ttop.BorderSizePixel = 0\n" +
                "\ttop.Parent = canvas\n\n" +
                "\tlocal bottom = Instance.new(\"Frame\")\n" +
                "\tbottom.Name = \"PipeBottom\"\n" +
                "\tbottom.Size = UDim2.new(pipeWidth, 0, bottomHeight, 0)\n" +
                "\tbottom.Position = UDim2.new(spawnX, 0, bottomY, 0)\n" +
                "\tbottom.BackgroundColor3 = CURRENT_THEME.PipeColor\n" +
                "\tbottom.BorderSizePixel = 0\n" +
                "\tbottom.Parent = canvas\n\n" +
                "\ttable.insert(pipes, { top = top, bottom = bottom, passed = false })\n" +
                "end\n\n" +
                "local function reset()\n" +
                "\tfor _, p2 in ipairs(pipes) do\n" +
                "\t\tif p2.top then p2.top:Destroy() end\n" +
                "\t\tif p2.bottom then p2.bottom:Destroy() end\n" +
                "\tend\n" +
                "\tpipes = {}\n" +
                "\tscore = 0\n" +
                "\tscoreLabel.Text = \"0\"\n" +
                "\tvelocity = 0\n" +
                "\tstate = \"Idle\"\n" +
                "\tbirdContainer.Position = UDim2.new(BIRD_X, 0, BIRD_Y_IDLE, 0)\n" +
                "\ttapButton.Visible = false\n" +
                "\tstartButton.Visible = true\n" +
                "\trestartButton.Visible = false\n" +
                "end\n\n" +
                "startButton.MouseButton1Click:Connect(function()\n" +
                "\tif state == \"Idle\" then\n" +
                "\t\tstate = \"Playing\"\n" +
                "\t\tstartButton.Visible = false\n" +
                "\t\ttapButton.Visible = true\n" +
                "\t\tcreatePipe(1)\n" +
                "\tend\n" +
                "end)\n\n" +
                "restartButton.MouseButton1Click:Connect(function()\n" +
                "\tif state == \"GameOver\" then reset() end\n" +
                "end)\n\n" +
                "local function jump()\n" +
                "\tif state ~= \"Playing\" then return end\n" +
                "\tvelocity = jumpForce\n" +
                "\tplaySound(\"Jump\")\n" +
                "end\n\n" +
                "tapButton.MouseButton1Click:Connect(jump)\n" +
                "UIS.InputBegan:Connect(function(input, gp)\n" +
                "\tif gp then return end\n" +
                "\tif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space then\n" +
                "\t\tif state == \"Playing\" then jump() end\n" +
                "\tend\n" +
                "end)\n\n" +
                "local function hitTest(a, b)\n" +
                "\tlocal ax, ay = a.AbsolutePosition.X, a.AbsolutePosition.Y\n" +
                "\tlocal aw, ah = a.AbsoluteSize.X, a.AbsoluteSize.Y\n" +
                "\tlocal bx, by = b.AbsolutePosition.X, b.AbsolutePosition.Y\n" +
                "\tlocal bw, bh = b.AbsoluteSize.X, b.AbsoluteSize.Y\n" +
                "\treturn ax < bx+bw and ax+aw > bx and ay < by+bh and ay+ah > by\n" +
                "end\n\n" +
                "RunService.RenderStepped:Connect(function(dt)\n" +
                "\tif state ~= \"Playing\" then return end\n" +
                "\tvelocity = math.min(velocity + gravity, maxFallSpeed)\n" +
                "\tbirdContainer.Position = UDim2.new(BIRD_X, 0, birdContainer.Position.Y.Scale + velocity, 0)\n" +
                "\tif birdContainer.Position.Y.Scale >= 0.85 or birdContainer.Position.Y.Scale <= 0 then\n" +
                "\t\tstate = \"GameOver\"\n" +
                "\t\ttapButton.Visible = false\n" +
                "\t\trestartButton.Visible = true\n" +
                "\t\tplaySound(\"GameOver\")\n" +
                "\t\treturn\n" +
                "\tend\n\n" +
                "\tfor i = #pipes, 1, -1 do\n" +
                "\t\tlocal pair = pipes[i]\n" +
                "\t\tlocal px = pair.bottom.Position.X.Scale\n" +
                "\t\tpair.bottom.Position = UDim2.new(px - pipeSpeed, 0, pair.bottom.Position.Y.Scale, 0)\n" +
                "\t\tpair.top.Position = UDim2.new(px - pipeSpeed, 0, pair.top.Position.Y.Scale, 0)\n" +
                "\t\tif (not pair.passed) and px < BIRD_X then\n" +
                "\t\t\tpair.passed = true\n" +
                "\t\t\tscore += 1\n" +
                "\t\t\tscoreLabel.Text = tostring(score)\n" +
                "\t\t\tplaySound(\"Score\")\n" +
                "\t\tend\n" +
                "\t\tif px < -0.2 then\n" +
                "\t\t\tpair.bottom:Destroy(); pair.top:Destroy(); table.remove(pipes, i)\n" +
                "\t\telseif hitTest(birdContainer, pair.bottom) or hitTest(birdContainer, pair.top) then\n" +
                "\t\t\tstate = \"GameOver\"\n" +
                "\t\t\ttapButton.Visible = false\n" +
                "\t\t\trestartButton.Visible = true\n" +
                "\t\t\tplaySound(\"GameOver\")\n" +
                "\t\t\treturn\n" +
                "\t\tend\n" +
                "\tend\n\n" +
                "\tif (#pipes == 0) or (pipes[#pipes].bottom.Position.X.Scale < 0.55) then\n" +
                "\t\tcreatePipe(1)\n" +
                "\tend\n" +
                "end)\n\n" +
                "print(\"Flappy started\")\n"
        });

        return {
            message: "⚡ Instant template build (flappy)",
            build: { version: 1, rootFolderName: "AI_Build", instances }
        };
    }
    // Only these 2 templates are supported for instant fallback.
    return null;
}

async function withRetries(fn, attempts = 2) {
    let lastErr = null;
    for (let i = 0; i < attempts; i++) {
        try {
            return await fn();
        } catch (e) {
            lastErr = e;
        }
    }
    throw lastErr;
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
    const preferTemplate = req.body.preferTemplate !== false;
    const attempts = Number(req.body.attempts || 2);

    const types = detectGameTypes(prompt);

    let finalCode = "";
    let plan = "";

    // ✅ STRUCTURED BUILD MODE (preferred: safer than executing AI Lua)
    if (structured) {
        // Fast fallback: return an instant structured template for Generate.
        if (action === "generate" && fast && preferTemplate) {
            const out = structuredTemplateBuildFromPrompt(prompt);
            if (out) {
                return res.json({
                    mode: "structured-template",
                    message: out.message,
                    build: out.build
                });
            }
        }

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

        const aiRes = await withRetries(
            () => openai.chat.completions.create({
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
                            "- className (e.g. Folder, Model, Part, MeshPart, SpawnLocation, ScreenGui, TextLabel, TextButton, BillboardGui, PointLight, Script, LocalScript, ModuleScript)\n" +
                            "- name (optional string)\n" +
                            "- parent (string id, or one of: 'workspace', 'ServerScriptService', 'StarterGui')\n" +
                            "- properties (object of simple values; use arrays for vectors: [x,y,z] and colors: [r,g,b])\n" +
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
            }),
            attempts
        );

        const raw = String(aiRes.choices?.[0]?.message?.content || "").trim();
        const parsed = safeJsonParse(raw);
        if (!parsed.ok) {
            // Fallback to instant template instead of Lua (faster + safer)
            const out = structuredTemplateBuildFromPrompt(prompt);
            if (out) {
                return res.json({
                    mode: "structured-fallback-template",
                    message: "⚠️ AI JSON failed; using template fallback.",
                    structuredError: "Invalid JSON from model",
                    build: out.build
                });
            }
            return res.json({
                mode: "structured-error",
                message: "⚠️ Structured mode: invalid JSON.",
                structuredError: "Invalid JSON from model"
            });
        }

        const out = parsed.value;
        const v = validateStructuredBuild(out.build);
        if (!v.ok) {
            const out2 = structuredTemplateBuildFromPrompt(prompt);
            if (out2) {
                return res.json({
                    mode: "structured-fallback-template",
                    message: "⚠️ AI build schema failed; using template fallback.",
                    structuredError: v.error,
                    build: out2.build
                });
            }
            return res.json({
                mode: "structured-error",
                message: "⚠️ Structured mode: invalid build schema.",
                structuredError: v.error
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
